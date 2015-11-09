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
    
    EventSource *source = [EventSource eventSourceWithURL:[NSURL URLWithString:@"http://192.168.99.100:8000"] withAuth:@"202e5de7d1c827bfcc434b650a48233514083ee2"];
    [source addEventListener:@"hello_event" handler:^(Event *e) {
        NSLog(@"%@: %@", e.event, e.data);
    }];
}

@end
