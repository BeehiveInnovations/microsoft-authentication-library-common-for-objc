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

#import "MSIDBrokerOperationTokenRequest.h"

@class MSIDConfiguration;
@class MSIDAccountIdentifier;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrokerOperationSilentTokenRequest : MSIDBrokerOperationTokenRequest

@property (nonatomic) MSIDAccountIdentifier *accountIdentifier;

@property (nonatomic, nullable) NSOrderedSet<NSString *> *extraScopesToConsent;
@property (nonatomic, nullable) NSOrderedSet<NSString *> *extraOIDCScopes;
@property (nonatomic, nullable) NSDictionary<NSString *, NSString *> *extraAuthorizeURLQueryParameters;
@property (nonatomic, nullable) NSArray<NSString *> *clientCapabilities;
/*! Claims is a json dictionary. It is not url encoded. */
@property (nonatomic, nullable) NSDictionary *claims;

@end

NS_ASSUME_NONNULL_END
