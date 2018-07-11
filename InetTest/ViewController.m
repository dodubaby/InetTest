//
//  ViewController.m
//  InetTest
//
//  Created by Daniel Nestor Corbatta Barreto on 20/11/13.
//  Copyright (c) 2013 Daniel Nestor Corbatta Barreto. All rights reserved.
//

#import "ViewController.h"
#import "DHInet.h"


@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"http://www.sina.com.cn"]];
    // Do any additional setup after loading the view, typically from a nib.
    [request setValue:@"" forHTTPHeaderField:@"Accept-Encoding"];
    //    NSURLConnection *connect = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    //    [connect start];
    
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    NSURLSessionTask *task = [session dataTaskWithRequest:request];
    
    [task resume];
    

    
}


- (void)viewDidAppear:(BOOL)animated
{
    DHInet * inet = [[DHInet alloc] init];
    
    NSArray * connections = [inet getTCPConnections];
    
    for (NSDictionary * connection in connections) {
        for (id key in connection) {
            NSLog(@"key: %@, value: %@ \n", key, [connection objectForKey:key]);
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
