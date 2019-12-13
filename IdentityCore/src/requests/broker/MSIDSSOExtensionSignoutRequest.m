// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSIDSSOExtensionSignoutRequest.h"

#if MSID_ENABLE_SSO_EXTENSION
#import <AuthenticationServices/AuthenticationServices.h>
#import "MSIDSSOExtensionOperationRequestDelegate.h"
#import "MSIDInteractiveRequestParameters.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDOauth2Factory.h"
#import "MSIDBrokerOperationSignoutFromDeviceRequest.h"
#import "NSDictionary+MSIDQueryItems.h"
#import "MSIDBrokerOperationRequest.h"
#import "MSIDBrokerOperationResponse.h"
#import "MSIDConfiguration.h"

@interface MSIDSSOExtensionSignoutRequest() <ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate>

@property (nonatomic) ASAuthorizationController *authorizationController;
@property (nonatomic, copy) MSIDSignoutRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) MSIDSSOExtensionOperationRequestDelegate *extensionDelegate;
@property (nonatomic) ASAuthorizationSingleSignOnProvider *ssoProvider;
@property (nonatomic, readonly) MSIDProviderType providerType;
@property (nonatomic) BOOL shouldSignoutFromBrowser;

@end

@implementation MSIDSSOExtensionSignoutRequest

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDInteractiveRequestParameters *)parameters
                          shouldSignoutFromBrowser:(BOOL)shouldSignoutFromBrowser
                                      oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
{
    self = [self initWithRequestParameters:parameters oauthFactory:oauthFactory];
    
    if (self)
    {
        _shouldSignoutFromBrowser = shouldSignoutFromBrowser;
    }
    
    return self;
}

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDInteractiveRequestParameters *)parameters
                                      oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
{
    self = [super initWithRequestParameters:parameters oauthFactory:oauthFactory];
    
    if (self)
    {
        _extensionDelegate = [MSIDSSOExtensionOperationRequestDelegate new];
        _extensionDelegate.context = parameters;
        __weak typeof(self) weakSelf = self;
        _extensionDelegate.completionBlock = ^(MSIDBrokerOperationResponse *operationResponse, NSError *error)
        {
            if (!operationResponse.success)
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, parameters, @"Finished logout request with error %@", MSID_PII_LOG_MASKABLE(error));
            }
            
            MSIDSignoutRequestCompletionBlock completionBlock = weakSelf.requestCompletionBlock;
            weakSelf.requestCompletionBlock = nil;
            
            if (completionBlock) completionBlock(operationResponse.success, error);
        };
        
        _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
        _providerType = [[oauthFactory class] providerType];
        _shouldSignoutFromBrowser = YES;
    }
    
    return self;
}

- (void)executeRequestWithCompletion:(nonnull MSIDSignoutRequestCompletionBlock)completionBlock
{
    if (!self.requestParameters.accountIdentifier)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Account parameter cannot be nil");
        
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorMissingAccountParameter, @"Account parameter cannot be nil", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
        completionBlock(NO, error);
        return;
    }
        
    MSIDBrokerOperationSignoutFromDeviceRequest *signoutRequest = [MSIDBrokerOperationSignoutFromDeviceRequest new];
    signoutRequest.clientId = self.requestParameters.msidConfiguration.clientId;
    signoutRequest.authority = self.requestParameters.msidConfiguration.authority;
    signoutRequest.redirectUri = self.requestParameters.msidConfiguration.redirectUri;
    signoutRequest.providerType = self.providerType;
    signoutRequest.accountIdentifier = self.requestParameters.accountIdentifier;
    signoutRequest.signoutFromBrowser = self.shouldSignoutFromBrowser;
    
    NSError *paramError;
    BOOL paramResult = [MSIDBrokerOperationRequest fillRequest:signoutRequest
                                           keychainAccessGroup:self.requestParameters.keychainAccessGroup
                                                clientMetadata:self.requestParameters.appRequestMetadata
                                                       context:self.requestParameters
                                                         error:&paramError];
    
    if (!paramResult)
    {
        completionBlock(NO, paramError);
        return;
    }
    
    ASAuthorizationSingleSignOnRequest *ssoRequest = [self.ssoProvider createRequest];
    ssoRequest.requestedOperation = [signoutRequest.class operation];
    __auto_type queryItems = [[signoutRequest jsonDictionary] msidQueryItems];
    ssoRequest.authorizationOptions = queryItems;
    
    self.authorizationController = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ssoRequest]];
    self.authorizationController.delegate = self.extensionDelegate;
    self.authorizationController.presentationContextProvider = self;
    [self.authorizationController performRequests];
    
    self.requestCompletionBlock = completionBlock;
}

#pragma mark - ASAuthorizationControllerPresentationContextProviding

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(__unused ASAuthorizationController *)controller
{
    return [self presentationAnchor];
}

- (ASPresentationAnchor)presentationAnchor
{
    if (![NSThread isMainThread])
    {
        __block ASPresentationAnchor anchor;
        dispatch_sync(dispatch_get_main_queue(), ^{
            anchor = [self presentationAnchor];
        });
        
        return anchor;
    }
    
    return self.requestParameters.parentViewController.view.window;
}


@end

#endif
