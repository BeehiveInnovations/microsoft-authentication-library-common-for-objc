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

#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDAccount.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDAccessToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDLegacyTokenCacheKey.h"
#import "MSIDConfiguration.h"
#import "MSIDTokenResponse.h"
#import "NSDate+MSIDExtensions.h"
#import "MSIDTokenFilteringHelper.h"
#import "MSIDAuthority.h"
#import "MSIDOauth2Factory.h"

@interface MSIDLegacyTokenCacheAccessor()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDKeyedArchiverSerializer *_serializer;
}

@end

@implementation MSIDLegacyTokenCacheAccessor

#pragma mark - Init

- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
{
    self = [super init];
    
    if (self)
    {
        _dataSource = dataSource;
        _serializer = [[MSIDKeyedArchiverSerializer alloc] init];
    }
    
    return self;
}

#pragma mark - MSIDSharedCacheAccessor

- (BOOL)saveTokensWithFactory:(MSIDOauth2Factory *)factory
                 configuration:(MSIDConfiguration *)configuration
                       account:(MSIDAccount *)account
                      response:(MSIDTokenResponse *)response
                       context:(id<MSIDRequestContext>)context
                         error:(NSError **)error
{
    if (response.isMultiResource)
    {
        // Save access token item in the primary format
        MSIDAccessToken *accessToken = [factory accessTokenFromResponse:response configuration:configuration];
        
        MSID_LOG_INFO(context, @"(Legacy accessor) Saving multi resource tokens in legacy accessor");
        MSID_LOG_INFO_PII(context, @"(Legacy accessor) Saving multi resource tokens in legacy accessor %@", accessToken);

        if (!accessToken)
        {
            MSID_LOG_ERROR(context, @"Couldn't initialize access token entry. Not updating cache");
            
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Tried to save access token, but no access token returned", nil, nil, nil, context.correlationId, nil);
            }
            
            return NO;
        }
        
        BOOL result = [self saveToken:accessToken
                              account:account
                              context:context
                                error:error];
        
        if (!result) return NO;
    }
    else
    {
        MSIDLegacySingleResourceToken *legacyToken = [factory legacyTokenFromResponse:response configuration:configuration];
        
        if (!legacyToken)
        {
            MSID_LOG_ERROR(context, @"Couldn't initialize ADFS token entry. Not updating cache");
            
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Tried to save ADFS token, but no ADFS token returned", nil, nil, nil, context.correlationId, nil);
            }
            
            return NO;
        }
        
        MSID_LOG_INFO(context, @"(Legacy accessor) Saving single resource tokens in legacy accessor");
        MSID_LOG_INFO_PII(context, @"(Legacy accessor) Saving single resource tokens in legacy accessor %@", legacyToken);
        
        account.legacyUserId = @"";
        
        // Save token for legacy single resource token
        return [self saveToken:legacyToken
                       account:account
                       context:context
                         error:error];
    }
    
    return YES;
}

- (BOOL)saveRefreshToken:(MSIDRefreshToken *)refreshToken
                 account:(MSIDAccount *)account
                 context:(id<MSIDRequestContext>)context
                   error:(NSError **)error
{
    return [self saveToken:refreshToken
                   account:account
                   context:context
                     error:error];
}

- (BOOL)saveAccessToken:(MSIDAccessToken *)accessToken
                account:(MSIDAccount *)account
                context:(id<MSIDRequestContext>)context
                  error:(NSError **)error
{
    return [self saveToken:accessToken
                   account:account
                   context:context
                     error:error];
}

- (BOOL)saveToken:(MSIDBaseToken *)token
          account:(MSIDAccount *)account
          context:(id<MSIDRequestContext>)context
            error:(NSError **)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_WRITE
                                                                           context:context];
    
    NSURL *newAuthority = [[MSIDAadAuthorityCache sharedInstance] cacheUrlForAuthority:token.authority context:context];
    
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Saving token %@ with authority %@, clientID %@", [MSIDTokenTypeHelpers tokenTypeAsString:token.tokenType], newAuthority, token.clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Saving token %@ for account %@ with authority %@, clientID %@", token, account, newAuthority, token.clientId);
    
    // The authority used to retrieve the item over the network can differ from the preferred authority used to
    // cache the item. As it would be awkward to cache an item using an authority other then the one we store
    // it with we switch it out before saving it to cache.
    token.authority = newAuthority;
    
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey keyWithAuthority:newAuthority
                                                                    clientId:cacheItem.clientId
                                                                    resource:cacheItem.target
                                                                legacyUserId:account.legacyUserId];
    
    BOOL result = [_dataSource saveToken:cacheItem
                                     key:key
                              serializer:_serializer
                                 context:context
                                   error:error];
    
    [self stopTelemetryEvent:event withItem:token success:result context:context];
    
    return result;
}

- (MSIDBaseToken *)getTokenWithType:(MSIDTokenType)tokenType
                            account:(MSIDAccount *)account
                      configuration:(MSIDConfiguration *)configuration
                            context:(id<MSIDRequestContext>)context
                              error:(NSError **)error
{
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    MSIDBaseToken *token = nil;
    
    // Do custom handling for refresh tokens, because they need fallback logic with different identifiers
    if (tokenType == MSIDTokenTypeRefreshToken)
    {
        token = [self getRefreshTokenWithAccount:account
                                   configuration:configuration
                                         context:context
                                           error:error];
    }
    else
    {
        token = [self getTokenByLegacyUserId:account.legacyUserId
                                   tokenType:tokenType
                                   authority:configuration.authority
                                    clientId:configuration.clientId
                                    resource:configuration.resource
                                     context:context
                                       error:error];
    }
    
    [self stopTelemetryLookupEvent:event tokenType:tokenType withToken:token success:token != nil context:context];
    return token;
}

- (MSIDBaseToken *)getLatestToken:(MSIDBaseToken *)token
                          account:(MSIDAccount *)account
                          context:(id<MSIDRequestContext>)context
                            error:(NSError **)error
{
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
    
    return [self getTokenByLegacyUserId:account.legacyUserId
                              tokenType:cacheItem.tokenType
                              authority:cacheItem.authority
                               clientId:cacheItem.clientId
                               resource:cacheItem.target
                                context:context
                                  error:error];
}

- (NSArray *)getAllTokensOfType:(MSIDTokenType)tokenType
                   withClientId:(NSString *)clientId
                        context:(id<MSIDRequestContext>)context
                          error:(NSError **)error
{
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Get all tokens of type %@ with clientId %@", [MSIDTokenTypeHelpers tokenTypeAsString:tokenType], clientId);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Get all tokens of type %@ with clientId %@", [MSIDTokenTypeHelpers tokenTypeAsString:tokenType], clientId);
    
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP];
    
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP
                                                                           context:context];
    
    NSArray<MSIDTokenCacheItem *> *legacyCacheItems = [_dataSource tokensWithKey:[MSIDLegacyTokenCacheKey queryForAllItems]
                                                                      serializer:_serializer
                                                                         context:context
                                                                           error:error];
    
    if (!legacyCacheItems)
    {
        [self stopTelemetryEvent:event withItem:nil success:NO context:context];
        return nil;
    }
    
    NSArray *results = [MSIDTokenFilteringHelper filterTokenCacheItems:legacyCacheItems
                                                             tokenType:tokenType
                                                           returnFirst:NO
                                                              filterBy:^BOOL(MSIDTokenCacheItem *cacheItem) {
                                                                  
                                                                  return (cacheItem.tokenType == tokenType
                                                                          && [cacheItem.clientId isEqualToString:clientId]);
                                                              }];
    
    [self stopTelemetryLookupEvent:event tokenType:tokenType withToken:nil success:(results.count > 0) context:context];
    
    return results;
}

- (NSArray<MSIDBaseToken *> *)allTokensWithContext:(id<MSIDRequestContext>)context
                                             error:(NSError **)error
{
    MSIDTokenCacheKey *key = [MSIDTokenCacheKey queryForAllItems];
    __auto_type items = [_dataSource tokensWithKey:key serializer:_serializer context:context error:error];
    
    NSMutableArray<MSIDBaseToken *> *tokens = [NSMutableArray new];
    
    for (MSIDTokenCacheItem *item in items)
    {
        MSIDBaseToken *token = [item tokenWithType:item.tokenType];
        if (token)
        {
            [tokens addObject:token];
        }
    }
    
    return tokens;
}

- (BOOL)removeToken:(MSIDBaseToken *)token
            account:(MSIDAccount *)account
            context:(id<MSIDRequestContext>)context
              error:(NSError **)error
{
    if (!token)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Token not provided", nil, nil, nil, context.correlationId, nil);
        }
        
        return NO;
    }
    
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Removing token with clientId %@, authority %@", token.clientId, token.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Removing token %@ with account %@", token, account);
    
    [[MSIDTelemetry sharedInstance] startEvent:[context telemetryRequestId]
                                     eventName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE];
    MSIDTelemetryCacheEvent *event = [[MSIDTelemetryCacheEvent alloc] initWithName:MSID_TELEMETRY_EVENT_TOKEN_CACHE_DELETE
                                                                           context:context];
    
    MSIDTokenCacheItem *cacheItem = token.tokenCacheItem;
 
    NSURL *authority = token.storageAuthority ? token.storageAuthority : token.authority;
    
    MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey keyWithAuthority:authority
                                                                    clientId:cacheItem.clientId
                                                                    resource:cacheItem.target
                                                                legacyUserId:account.legacyUserId];
    
    BOOL result = [_dataSource removeItemsWithKey:key
                                          context:context
                                            error:error];

    if (result && token.tokenType == MSIDTokenTypeRefreshToken)
    {
        [_dataSource saveWipeInfoWithContext:context error:nil];
    }
    
    [self stopTelemetryEvent:event withItem:nil success:result context:context];
    return result;
}

- (BOOL)removeAccount:(MSIDAccount *)account
              context:(id<MSIDRequestContext>)context
                error:(NSError **)error
{
    // We don't suppport account in legacy cache.
    return YES;
}

- (BOOL)removeAllTokensForAccount:(MSIDAccount *)account context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error
{
    MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey queryWithAuthority:nil clientId:nil resource:nil legacyUserId:account.legacyUserId];
    
    return [_dataSource removeItemsWithKey:key context:context error:error];
}

- (BOOL)clearWithContext:(id<MSIDRequestContext>)context error:(NSError **)error
{
    return [_dataSource removeItemsWithKey:[MSIDTokenCacheKey queryForAllItems] context:nil error:error];
}

#pragma mark - Private

- (MSIDBaseToken *)getRefreshTokenWithAccount:(MSIDAccount *)account
                                configuration:(MSIDConfiguration *)configuration
                                      context:(id<MSIDRequestContext>)context
                                        error:(NSError **)error
{
    if ([MSIDAuthority isConsumerInstanceURL:configuration.authority])
    {
        return nil;
    }
    
    MSID_LOG_VERBOSE(context, @"(Legacy accessor) Finding refresh token with legacy user ID, clientId %@, authority %@", configuration.clientId, configuration.authority);
    MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Finding refresh token with legacy user ID %@, clientId %@, authority %@", account.legacyUserId, configuration.clientId, configuration.authority);
    
    MSIDBaseToken *resultToken = [self getTokenByLegacyUserId:account.legacyUserId
                                                    tokenType:MSIDTokenTypeRefreshToken
                                                    authority:configuration.authority
                                                     clientId:configuration.clientId
                                                     resource:nil
                                                      context:context
                                                        error:error];
    
    // If no legacy user ID available, or no token found by legacy user ID, try to look by unique user ID
    if (!resultToken
        && ![NSString msidIsStringNilOrBlank:account.uniqueUserId])
    {
        NSURL *authority = [MSIDAuthority universalAuthorityURL:configuration.authority];
        
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Finding refresh token with new user ID, clientId %@, authority %@", configuration.clientId, authority);
        MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Finding refresh token with new user ID %@, clientId %@, authority %@", account.uniqueUserId, configuration.clientId, authority);
        
        return [self getTokenByUniqueUserId:account.uniqueUserId
                                  tokenType:MSIDTokenTypeRefreshToken
                                  authority:authority
                                   clientId:configuration.clientId
                                   resource:nil
                                    context:context
                                      error:error];
    }
    
    return resultToken;
}

- (MSIDBaseToken *)getTokenByLegacyUserId:(NSString *)legacyUserId
                                tokenType:(MSIDTokenType)tokenType
                                authority:(NSURL *)authority
                                 clientId:(NSString *)clientId
                                 resource:(NSString *)resource
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    NSArray<NSURL *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authority];
    
    for (NSURL *alias in aliases)
    {
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Looking for token with alias %@, clientId %@, resource %@", alias, clientId, resource);
        MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Looking for token with alias %@, clientId %@, resource %@, legacy userId %@", alias, clientId, resource, legacyUserId);
        
        MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey queryWithAuthority:alias
                                                                          clientId:clientId
                                                                          resource:resource
                                                                      legacyUserId:legacyUserId];
        
        if (!key)
        {
            return nil;
        }
        
        NSError *cacheError = nil;
        MSIDTokenCacheItem *cacheItem = [_dataSource tokenWithKey:key serializer:_serializer context:context error:&cacheError];
        
        if (cacheError)
        {
            if (error) *error = cacheError;
            return nil;
        }
        
        if (cacheItem)
        {
            MSIDBaseToken *token = [cacheItem tokenWithType:tokenType];
            token.storageAuthority = token.authority;
            token.authority = authority;
            return token;
        }
    }
    
    return nil;
}

- (MSIDBaseToken *)getTokenByUniqueUserId:(NSString *)uniqueUserId
                                tokenType:(MSIDTokenType)tokenType
                                authority:(NSURL *)authority
                                 clientId:(NSString *)clientId
                                 resource:(NSString *)resource
                                  context:(id<MSIDRequestContext>)context
                                    error:(NSError **)error
{
    NSArray<NSURL *> *aliases = [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:authority];
    
    for (NSURL *alias in aliases)
    {
        MSID_LOG_VERBOSE(context, @"(Legacy accessor) Looking for token with alias %@, clientId %@, resource %@", alias, clientId, resource);
        MSID_LOG_VERBOSE_PII(context, @"(Legacy accessor) Looking for token with alias %@, clientId %@, resource %@, unique userId %@", alias, clientId, resource, uniqueUserId);
        
        MSIDLegacyTokenCacheKey *key = [MSIDLegacyTokenCacheKey queryWithAuthority:alias
                                                                          clientId:clientId
                                                                          resource:resource
                                                                      legacyUserId:nil];
        
        if (!key)
        {
            return nil;
        }
        
        NSError *cacheError = nil;
        NSArray *tokens = [_dataSource tokensWithKey:key serializer:_serializer context:context error:&cacheError];
        
        if (cacheError)
        {
            if (error) *error = cacheError;
            return nil;
        }
        
        BOOL (^filterBlock)(MSIDTokenCacheItem *cacheItem) = ^BOOL(MSIDTokenCacheItem *cacheItem) {
            return [cacheItem.uniqueUserId isEqualToString:uniqueUserId];
        };
        
        NSArray *matchedTokens = [MSIDTokenFilteringHelper filterTokenCacheItems:tokens
                                                                       tokenType:tokenType
                                                                     returnFirst:YES
                                                                        filterBy:filterBlock];
        
        if ([matchedTokens count])
        {
            MSIDBaseToken *token = matchedTokens[0];
            token.storageAuthority = token.authority;
            token.authority = authority;
            return token;
        }
    }
    
    return nil;
}

#pragma mark - Telemetry helpers

- (void)stopTelemetryEvent:(MSIDTelemetryCacheEvent *)event
                  withItem:(MSIDBaseToken *)token
                   success:(BOOL)success
                   context:(id<MSIDRequestContext>)context
{
    [event setStatus:success ? MSID_TELEMETRY_VALUE_SUCCEEDED : MSID_TELEMETRY_VALUE_FAILED];
    if (token)
    {
        [event setToken:token];
    }
    [[MSIDTelemetry sharedInstance] stopEvent:[context telemetryRequestId]
                                        event:event];
}

- (void)stopTelemetryLookupEvent:(MSIDTelemetryCacheEvent *)event
                       tokenType:(MSIDTokenType)tokenType
                       withToken:(MSIDBaseToken *)token
                         success:(BOOL)success
                         context:(id<MSIDRequestContext>)context
{
    if (!success && tokenType == MSIDTokenTypeRefreshToken)
    {
        [event setWipeData:[_dataSource wipeInfo:context error:nil]];
    }
    
    [self stopTelemetryEvent:event
                    withItem:token
                     success:success
                     context:context];
}

@end
