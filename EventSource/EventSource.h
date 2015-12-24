//
//  EventSource.h
//  EventSource
//
//  Created by Neil on 25/07/2013.
//  Copyright (c) 2013 Neil Cowburn. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    kEventStateConnecting = 0,
    kEventStateOpen = 1,
    kEventStateClosed = 2,
} EventState;
// ---------------------------------------------------------------------------------------------------------------------

/// Describes an Event received from an EventSource
@interface Event : NSObject

/// The Event ID
@property (nonatomic, strong) id id;
/// The name of the Event
@property (nonatomic, strong) NSString *event;
/// The data received from the EventSource
@property (nonatomic, strong) NSString *data;

/// The current state of the connection to the EventSource
@property (nonatomic, assign) EventState readyState;
/// Provides details of any errors with the connection to the EventSource
@property (nonatomic, strong) NSError *error;

@end

// ---------------------------------------------------------------------------------------------------------------------

typedef void (^EventSourceEventHandler)(Event *event);

// ---------------------------------------------------------------------------------------------------------------------

/// Connect to and receive Server-Sent Events (SSEs).
@interface EventSource : NSObject

/// Returns a new instance of EventSource with the specified URL and auth token.
///
/// @param URL The URL of the EventSource.
/// @param authValue The auth token value to use for the event request
+ (instancetype)eventSourceWithURL:(NSURL *)URL withAuth:(NSString *)authValue;

/*!
 *  Returns a new instance of EventSource with the specified URL, auth token, and retry interval
 *
 *  @param URL           The URL of the EventSource.
 *  @param authValue     The auth token value to use for the event request
 *  @param retryInterval The interval at which the library should attempt to reconnect
 */
+ (instancetype)eventSourceWithURL:(NSURL *)URL withAuth:(NSString *)authValue retryInterval:(NSTimeInterval)retryInterval;

/// Returns a new instance of EventSource with the specified URL auth token, and timeout interval.
///
/// @param URL The URL of the EventSource.
/// @param timeoutInterval The request timeout interval in seconds. See <tt>NSURLRequest</tt> for more details. Default: 5 minutes.
+ (instancetype)eventSourceWithURL:(NSURL *)URL withAuth:(NSString *)authValue timeoutInterval:(NSTimeInterval)timeoutInterval ;

/*!
 *  Returns a new instance of EventSource with the specified URL auth token, timeout interval, and retry interval.
 *
 *  @param URL             The URL of the EventSource.
 *  @param authValue       The auth token value to use for the event request
 *  @param timeoutInterval The request timeout interval in seconds. See <tt>NSURLRequest</tt> for more details. Default: 5 minutes.
 *  @param retryInterval   The interval at which the library should attempt to reconnect
 */
+ (instancetype)eventSourceWithURL:(NSURL *)URL withAuth:(NSString *)authValue timeoutInterval:(NSTimeInterval)timeoutInterval retryInterval:(NSTimeInterval)retryInterval;

/// Creates a new instance of EventSource with the specified URL.
///
/// @param URL              The URL of the EventSource.
/// @param authValue        The auth token value to use for the event request
/// @param timeoutInterval  The request timeout interval in seconds. See <tt>NSURLRequest</tt> for more details. Default: 5 minutes.
/// @param retryInterval    The interval at which the library should attempt to reconnect
- (instancetype)initWithURL:(NSURL *)URL withAuth:(NSString *)authValue timeoutInterval:(NSTimeInterval)timeoutInterval retryInterval:(NSTimeInterval)retryInterval;

/// Registers an event handler for the Message event.
///
/// @param handler The handler for the Message event.
- (void)onMessage:(EventSourceEventHandler)handler;

/// Registers an event handler for the Error event.
///
/// @param handler The handler for the Error event.
- (void)onError:(EventSourceEventHandler)handler;

/// Registers an event handler for the Open event.
///
/// @param handler The handler for the Open event.
- (void)onOpen:(EventSourceEventHandler)handler;

/// Registers an event handler for a named event.
///
/// @param eventName The name of the event you registered.
/// @param handler The handler for the Message event.
- (void)addEventListener:(NSString *)eventName handler:(EventSourceEventHandler)handler;

/// Closes the connection to the EventSource.
- (void)close;

/// Opens the connection to the EventSource.
- (void)open;

@end

// ---------------------------------------------------------------------------------------------------------------------

extern NSString *const MessageEvent;
extern NSString *const ErrorEvent;
extern NSString *const OpenEvent;
