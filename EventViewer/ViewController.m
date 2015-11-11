//
//  ViewController.m
//  EventViewer
//
//  Created by Neil on 25/07/2013.
//  Copyright (c) 2013 Neil Cowburn. All rights reserved.
//

#import "ViewController.h"
#import "EventSource.h"

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    EventSource *source = [EventSource eventSourceWithURL:[NSURL URLWithString:@"http://192.168.99.100:8001/subscribe"] withAuth:@"Token 202e5de7d1c827bfcc434b650a48233514083ee2"];
//    [source open];
    
    [source addEventListener:@"patient_added" handler:^(Event *e) {
        NSLog(@"%@: %@", e.event, e.data);
    }];
    
    [source onOpen:^(Event *event) {
        NSLog(@"Log something.  Log anything");
    }];
    
    [source onMessage:^(Event *event) {
        NSLog(@"Log something.  Log anything");
    }];
}

@end
