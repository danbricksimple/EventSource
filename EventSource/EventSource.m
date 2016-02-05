//
//  EventSource.m
//  EventSource
//
//  Created by Neil on 25/07/2013.
//  Copyright (c) 2013 Neil Cowburn. All rights reserved.
//

#import "EventSource.h"
#import <CoreGraphics/CGBase.h>

static CGFloat const ES_RETRY_INTERVAL = 1.0;
static CGFloat const ES_DEFAULT_TIMEOUT = 300.0;

static NSString *const ESKeyValueDelimiter = @": ";
static NSString *const ESEventSeparatorLFLF = @"\n\n";
static NSString *const ESEventSeparatorCRCR = @"\r\r";
static NSString *const ESEventSeparatorCRLFCRLF = @"\r\n\r\n";
static NSString *const ESEventKeyValuePairSeparator = @"\n";

static NSString *const ESEventDataKey = @"data";
static NSString *const ESEventIDKey = @"id";
static NSString *const ESEventEventKey = @"event";
static NSString *const ESEventRetryKey = @"retry";

@interface EventSource () <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
    BOOL wasClosed;
    NSString *dataString;
}

@property (nonatomic, strong) NSURL *eventURL;
@property (nonatomic, strong) NSString *authToken;
@property (nonatomic, strong) NSURLConnection *eventSource;
@property (nonatomic, strong) NSMutableDictionary *listeners;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, assign) NSTimeInterval retryInterval;
@property (nonatomic, strong) id lastEventID;

- (void)open;

@end

@implementation EventSource

+ (instancetype)eventSourceWithURL:(NSURL *)URL withAuth:(NSString *)authValue
{
    return [[EventSource alloc] initWithURL:URL withAuth:authValue timeoutInterval:ES_DEFAULT_TIMEOUT retryInterval:ES_RETRY_INTERVAL];
}

+ (instancetype)eventSourceWithURL:(NSURL *)URL withAuth:(NSString *)authValue timeoutInterval:(NSTimeInterval)timeoutInterval
{
    return [[EventSource alloc] initWithURL:URL withAuth:authValue timeoutInterval:timeoutInterval retryInterval:ES_RETRY_INTERVAL];
}

+(instancetype)eventSourceWithURL:(NSURL *)URL withAuth:(NSString *)authValue retryInterval:(NSTimeInterval)retryInterval
{
    return [[EventSource alloc] initWithURL:URL withAuth:authValue timeoutInterval:ES_DEFAULT_TIMEOUT retryInterval:retryInterval];
}

+(instancetype)eventSourceWithURL:(NSURL *)URL withAuth:(NSString *)authValue timeoutInterval:(NSTimeInterval)timeoutInterval retryInterval:(NSTimeInterval)retryInterval
{
    return [[EventSource alloc] initWithURL:URL withAuth:authValue timeoutInterval:timeoutInterval retryInterval:retryInterval];
}

- (instancetype)initWithURL:(NSURL *)URL withAuth:(NSString *)authValue timeoutInterval:(NSTimeInterval)timeoutInterval retryInterval:(NSTimeInterval)retryInterval
{
    self = [super init];
    if (self) {
        _listeners = [NSMutableDictionary dictionary];
        _eventURL = URL;
        _timeoutInterval = timeoutInterval;
        _retryInterval = retryInterval;
        _authToken = authValue;

        dataString = @"";

        [self open];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"EventSource object removed");
}

- (void)addEventListener:(NSString *)eventName handler:(EventSourceEventHandler)handler
{
    if (self.listeners[eventName] == nil) {
        [self.listeners setObject:[NSMutableArray array] forKey:eventName];
    }
    
    [self.listeners[eventName] addObject:handler];
}

- (void)onMessage:(EventSourceEventHandler)handler
{
    [self addEventListener:MessageEvent handler:handler];
}

- (void)onError:(EventSourceEventHandler)handler
{
    [self addEventListener:ErrorEvent handler:handler];
}

- (void)onOpen:(EventSourceEventHandler)handler
{
    [self addEventListener:OpenEvent handler:handler];
}

- (void)open
{
    wasClosed = NO;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.eventURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:self.timeoutInterval];
    [request setValue:self.authToken forHTTPHeaderField:@"Authorization"];
    
    if (self.lastEventID) {
        [request setValue:self.lastEventID forHTTPHeaderField:@"Last-Event-ID"];
    }

    self.eventSource = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.eventSource start];
    });
}

- (void)close
{
    wasClosed = YES;
    [self.eventSource cancel];
    self.eventSource = nil;
}

// ---------------------------------------------------------------------------------------------------------------------

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode == 200) {
        // Opened
        Event *e = [Event new];
        e.readyState = kEventStateOpen;
        
        NSArray *openHandlers = self.listeners[OpenEvent];
        for (EventSourceEventHandler handler in openHandlers) {
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(e);
            });
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    Event *e = [Event new];
    e.readyState = kEventStateClosed;
    e.error = error;
    
    NSArray *errorHandlers = self.listeners[ErrorEvent];
    for (EventSourceEventHandler handler in errorHandlers) {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(e);
        });
    }

    __weak typeof(self) weakSelf = self;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.retryInterval * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [weakSelf open];
    });
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSString *incomingString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self parseEvent:incomingString];
}

-(void) parseEvent:(NSString*)incomingString
{
    dataString = [dataString stringByAppendingString:incomingString];

    //dataString might contain multiple events, separate by the ending delimiter
    NSArray *eventStrings = [dataString componentsSeparatedByString:@"\n\n"];

    //If the eventStrings is only 1 component long we do not have a complete event
    if ( eventStrings.count <= 1 )
    {
        return;
    }

    NSMutableArray *events = [[NSMutableArray alloc] init];

    //Ignore the last event, it is either an empty string or an incomplete event
    for ( int i = 0; i < eventStrings.count-1; ++i )
    {
        NSString *eventString = eventStrings[i];
        NSArray *eventComponents = [eventString componentsSeparatedByString:ESEventKeyValuePairSeparator];
        Event *e = [Event new];
        e.readyState = kEventStateOpen;

        for (NSString *component in eventComponents)
        {
            if (component.length == 0)
            {
                continue;
            }

            NSInteger index = [component rangeOfString:ESKeyValueDelimiter].location;
            if (index == NSNotFound || index == (component.length - 2)) {
                continue;
            }

            NSString *key = [component substringToIndex:index];
            NSString *value = [component substringFromIndex:index + ESKeyValueDelimiter.length];

            if ([key isEqualToString:ESEventIDKey])
            {
                e.id = value;
                self.lastEventID = e.id;
            }
            else if ([key isEqualToString:ESEventEventKey])
            {
                e.event = value;
            }
            else if ([key isEqualToString:ESEventDataKey])
            {
                e.data = value;
            }
            else if ([key isEqualToString:ESEventRetryKey])
            {
                self.retryInterval = [value doubleValue];
            }
        }

        if ( e.event != nil )
        {
            [events addObject:e];
        }
    }

    //Clear out the saved strings
    dataString = @"";

    //If there is an incomplete event at the end, save it
    NSString *lastString = [eventStrings lastObject];
    if ( lastString.length > 0 )
    {
        dataString = lastString;
    }

    for ( Event *e in events )
    {
        NSArray *messageHandlers = self.listeners[MessageEvent];
        for (EventSourceEventHandler handler in messageHandlers)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(e);
            });
        }

        if (e.event != nil)
        {
            NSArray *namedEventhandlers = self.listeners[e.event];
            for (EventSourceEventHandler handler in namedEventhandlers)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(e);
                });
            }
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (wasClosed) {
        return;
    }
    
    Event *e = [Event new];
    e.readyState = kEventStateClosed;
    e.error = [NSError errorWithDomain:@""
                                  code:e.readyState
                              userInfo:@{ NSLocalizedDescriptionKey: @"Connection with the event source was closed." }];
    
    NSArray *errorHandlers = self.listeners[ErrorEvent];
    for (EventSourceEventHandler handler in errorHandlers) {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(e);
        });
    }
    
    [self open];
}

@end

// ---------------------------------------------------------------------------------------------------------------------

@implementation Event

- (NSString *)description
{
    NSString *state = nil;
    switch (self.readyState) {
        case kEventStateConnecting:
            state = @"CONNECTING";
            break;
        case kEventStateOpen:
            state = @"OPEN";
            break;
        case kEventStateClosed:
            state = @"CLOSED";
            break;
    }
    
    return [NSString stringWithFormat:@"<%@: readyState: %@, id: %@; event: %@; data: %@>",
            [self class],
            state,
            self.id,
            self.event,
            self.data];
}

@end

NSString *const MessageEvent = @"message";
NSString *const ErrorEvent = @"error";
NSString *const OpenEvent = @"open";
