//
//  WebCodeEditor.m
//  APITesterPro
//
//  Created by Jaseem V V on 06.04.2024.
//  Copyright © 2024 Jaseem V V. All rights reserved.
//

#import "WebCodeEditor.h"
#import "APITesterPro-Swift.h"

@interface WebCodeEditor ()
@property (nonatomic, strong) App *app;
@end

@implementation WebCodeEditor

- (instancetype)init {
    self = [super init];
    if (self) {
        self.app = [App shared];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.app updateViewBackground:self.view];
    [self.app updateNavigationControllerBackground:self.navigationController];
    [Log debug:@"webcodeeditor view did load"];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(50, 100, 300, 50)];
    label.text = @"foo bar";
    [self.view addSubview:label];
}

@end
