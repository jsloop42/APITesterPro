//
//  WebCodeEditorViewController.h
//  APITesterPro
//
//  Created by Jaseem V V on 06.04.2024.
//  Copyright © 2024 Jaseem V V. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 Code editor using a web view.
 */
@interface WebCodeEditorViewController : UIViewController<WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>
@property (nonatomic, strong) NSString *text;
@end

NS_ASSUME_NONNULL_END
