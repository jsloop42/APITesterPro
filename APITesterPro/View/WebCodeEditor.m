//
//  WebCodeEditor.m
//  APITesterPro
//
//  Created by Jaseem V V on 06.04.2024.
//  Copyright © 2024 Jaseem V V. All rights reserved.
//

#import "WebCodeEditor.h"
#import "APITesterPro-Swift.h"
#import <WebKit/WebKit.h>
#import "Utils.h"

@interface WebCodeEditor ()
@property (nonatomic, strong) App *app;
@property (nonatomic, strong) WKWebView *webView;
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
    debug(@"webcodeeditor view did load");
    [self initUI];
}

- (void)initUI {
    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds];
    [self.webView setBackgroundColor:UIColor.blackColor];
    [self.view addSubview:self.webView];
    NSString *editorFile = [[NSBundle mainBundle] pathForResource:@"editor" ofType:@"html"];
    debug(@"editor file %@", editorFile);
    NSURL *htmlURL = [NSURL fileURLWithPath:editorFile];
    if (htmlURL) {
        NSURL *baseURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        [self.webView loadFileURL:htmlURL allowingReadAccessToURL:baseURL];
    } else {
        error(@"Error getting URL from editor file");
    }
}

@end
