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

#import <XCTest/XCTest.h>
#import "MSIDAadAuthorityCache.h"
#import "MSIDAadAuthorityCacheRecord.h"

@interface MSIDAadAuthorityCache ()

- (NSURL *)networkUrlForAuthorityImpl:(NSURL *)authority;
- (NSURL *)cacheUrlForAuthorityImpl:(NSURL *)authority;

@end

@interface MSIDAadAuthorityCacheTests : XCTestCase

@end

@implementation MSIDAadAuthorityCacheTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - Tests


#pragma mark -
#pragma mark Network URL Utility Tests

- (void)testNetworkUrlForAuthority_whenCachedNotValid_shouldReturnSameURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    [cache setObject:[MSIDAadAuthorityCacheRecord new] forKey:@"fakeauthority.com"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache networkUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(authority, cachedAuthority);
}

- (void)testNetworkUrlForAuthority_whenCachedNotValidWithPort_shouldReturnSameURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    [cache setObject:[MSIDAadAuthorityCacheRecord new] forKey:@"fakeauthority.com:444"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com:444/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache networkUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(authority, cachedAuthority);
}

- (void)testNetworkUrlForAuthority_whenCachedValidNoPreferredNetwork_shouldReturnSameURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    [cache setObject:record forKey:@"fakeauthority.com"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache networkUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(authority, cachedAuthority);
}

- (void)testNetworkUrlForAuthority_whenCacheMismatchOnPort_shouldReturnNil
{
    MSIDAadAuthorityCache *cache = [MSIDAadAuthorityCache sharedInstance];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    [cache setObject:record forKey:@"fakeauthority.com"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com:444/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache networkUrlForAuthorityImpl:authority];
    
    XCTAssertNil(cachedAuthority);
}

- (void)testNetworkUrlForAuthority_whenCachedValidSamePreferredNetwork_shouldReturnSameURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.networkHost = @"fakeauthority.com";
    [cache setObject:record forKey:@"fakeauthority.com"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache networkUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(authority, cachedAuthority);
}

- (void)testNetworkUrlForAuthority_whenCachedValidDifferentPreferredNetwork_shouldReturnPreferredURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.networkHost = @"preferredauthority.com";
    [cache setObject:record forKey:@"fakeauthority.com"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSURL *expectedAuthority = [NSURL URLWithString:@"https://preferredauthority.com/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache networkUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(expectedAuthority, cachedAuthority);
}

- (void)testNetworkUrlForAuthority_whenCachedValidDifferentPreferredNetworkAndURLContainsNonStandardPort_shouldReturnPreferredURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.networkHost = @"preferredauthority.com:444";
    [cache setObject:record forKey:@"fakeauthority.com:444"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com:444/v2/oauth/endpoint"];
    NSURL *expectedAuthority = [NSURL URLWithString:@"https://preferredauthority.com:444/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache networkUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(expectedAuthority, cachedAuthority);
}

- (void)testNetworkUrlForAuthority_whenCachedValidDifferentPreferredNetworkAndURLContainsPort_shouldReturnPreferredURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.networkHost = @"preferredauthority.com";
    [cache setObject:record forKey:@"fakeauthority.com"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com:443/v2/oauth/endpoint"];
    NSURL *expectedAuthority = [NSURL URLWithString:@"https://preferredauthority.com/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache networkUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(expectedAuthority, cachedAuthority);
}

#pragma mark -
#pragma mark Cache URL Utility Tests

- (void)testCacheUrlForAuthority_whenNotCached_shouldReturnNil
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache cacheUrlForAuthorityImpl:authority];
    
    XCTAssertNil(cachedAuthority);
}

- (void)testCacheUrlForAuthority_whenCachedNotValid_shouldReturnSameURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    [cache setObject:[MSIDAadAuthorityCacheRecord new] forKey:@"fakeauthority.com"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache cacheUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(authority, cachedAuthority);
}

- (void)testCacheUrlForAuthority_whenCachedNotValidWithPort_shouldReturnSameURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    [cache setObject:[MSIDAadAuthorityCacheRecord new] forKey:@"fakeauthority.com:444"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com:444/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache cacheUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(authority, cachedAuthority);
}

- (void)testCacheUrlForAuthority_whenCacheMismatchOnPort_shouldReturnNil
{
    MSIDAadAuthorityCache *cache = [MSIDAadAuthorityCache sharedInstance];
    [cache setObject:[MSIDAadAuthorityCacheRecord new] forKey:@"fakeauthority.com"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com:444/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache cacheUrlForAuthorityImpl:authority];
    
    XCTAssertNil(cachedAuthority);
}


- (void)testCacheUrlForAuthority_whenCachedValidNoPreferredCache_shouldReturnSameURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    [cache setObject:record forKey:@"fakeauthority.com"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache cacheUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(authority, cachedAuthority);
}

- (void)testCacheUrlForAuthority_whenCachedValidSameCacheNetwork_shouldReturnSameURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.cacheHost = @"fakeauthority.com";
    [cache setObject:record forKey:@"fakeauthority.com"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache cacheUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(authority, cachedAuthority);
}

- (void)testCacheUrlForAuthority_whenCachedValidDifferentPreferredNetwork_shouldReturnPreferredURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.cacheHost = @"preferredauthority.com";
    [cache setObject:record forKey:@"fakeauthority.com"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSURL *expectedAuthority = [NSURL URLWithString:@"https://preferredauthority.com/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache cacheUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(expectedAuthority, cachedAuthority);
}

- (void)testCacheUrlForAuthority_whenCachedValidDifferentPreferredNetworkAndUrlIncludesPort_shouldReturnPreferredURL
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.cacheHost = @"preferredauthority.com";
    [cache setObject:record forKey:@"fakeauthority.com"];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com:443/v2/oauth/endpoint"];
    NSURL *expectedAuthority = [NSURL URLWithString:@"https://preferredauthority.com/v2/oauth/endpoint"];
    
    NSURL *cachedAuthority = [cache cacheUrlForAuthorityImpl:authority];
    
    XCTAssertNotNil(cachedAuthority);
    XCTAssertEqualObjects(expectedAuthority, cachedAuthority);
}

#pragma mark -
#pragma mark Cache Aliases tests

- (void)testCacheAliasesForAuthority_whenNilAuhority_shouldReturnEmptyArray
{
    MSIDAadAuthorityCache *cache = [MSIDAadAuthorityCache new];
    
    NSArray *aliases = [cache cacheAliasesForAuthority:nil];
    
    XCTAssertEqualObjects(aliases, @[]);
}

- (void)testCacheAliasesForAuthority_whenNilCache_shouldReturnArrayWithAuthority
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://login.contoso.com/endpoint"];
    
    NSArray *aliases = [cache cacheAliasesForAuthority:authority];
    
    XCTAssertEqualObjects(aliases, @[authority]);
}

- (void)testCacheAliasesForAuthority_withNoMetadata_shouldReturnArrayWithAuthority
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://login.contoso.com/endpoint"];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    [cache setObject:record forKey:@"login.contoso.com"];
    
    NSArray *aliases = [cache cacheAliasesForAuthority:authority];
    
    XCTAssertEqualObjects(aliases, @[authority]);
}

- (void)testCacheAliasesForAuthority_withSimpleMetadata_shouldReturnArrayWithAuthority
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://login.contoso.com/endpoint"];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.networkHost = @"login.contoso.com";
    record.cacheHost = @"login.contoso.com";
    record.aliases = @[ @"login.contoso.com" ];
    [cache setObject:record forKey:@"login.contoso.com"];
    
    NSArray *aliases = [cache cacheAliasesForAuthority:authority];
    
    XCTAssertEqualObjects(aliases, @[authority]);
}

- (void)testCacheAliasesForAuthority_withDifferentPreferredCache_shouldReturnArrayInProperOrder
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://login.contoso.com/endpoint"];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.networkHost = @"login.contoso.com";
    record.cacheHost = @"login.contoso.net";
    record.aliases = @[ @"sts.contoso.com", @"login.contoso.net", @"sts.contoso.net", @"login.contoso.com" ];
    [cache setObject:record forKey:@"login.contoso.com"];
                          // cacheAliasesForAuthority should be returning the preferred host first
    NSArray *expected = @[[NSURL URLWithString:@"https://login.contoso.net/endpoint"],
                          // The host the API was called with second
                          authority,
                          // And then any remaining hosts in the alias list
                          [NSURL URLWithString:@"https://sts.contoso.com/endpoint"],
                          [NSURL URLWithString:@"https://sts.contoso.net/endpoint"]];
    
    NSArray *aliases = [cache cacheAliasesForAuthority:authority];
    
    XCTAssertEqualObjects(aliases, expected);
}

- (void)testCacheAliasesForAuthority_withPortDifferentPreferredCache_shouldReturnArrayInProperOrder
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://login.contoso.com:8888/endpoint"];
    __auto_type record = [MSIDAadAuthorityCacheRecord new];
    record.validated = YES;
    record.networkHost = @"login.contoso.com:8888";
    record.cacheHost = @"login.contoso.net:9000";
    record.aliases = @[ @"sts.contoso.com", @"login.contoso.net:9000", @"sts.contoso.net", @"login.contoso.com:8888" ];
    [cache setObject:record forKey:@"login.contoso.com:8888"];
    // cacheAliasesForAuthority should be returning the preferred host first
    NSArray *expected = @[[NSURL URLWithString:@"https://login.contoso.net:9000/endpoint"],
                          // The host the API was called with second
                          authority,
                          // And then any remaining hosts in the alias list
                          [NSURL URLWithString:@"https://sts.contoso.com/endpoint"],
                          [NSURL URLWithString:@"https://sts.contoso.net/endpoint"]];
    
    NSArray *aliases = [cache cacheAliasesForAuthority:authority];
    
    XCTAssertEqualObjects(aliases, expected);
}

#pragma mark -
#pragma mark Process Metadata tests

- (void)testProcessMetadata_whenNilMetadata_shouldCreateDefaultEntry
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com";
    
    NSError *error = nil;
    XCTAssertTrue([cache processMetadata:nil openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    XCTAssertNil(error);
    MSIDAadAuthorityCacheRecord *record = [cache objectForKey:expectedHost];
    XCTAssertNotNil(record);
    XCTAssertEqualObjects(expectedHost, record.networkHost);
    XCTAssertEqualObjects(expectedHost, record.cacheHost);
    XCTAssertNil(record.aliases);
}

- (void)testProcessMetadata_whenMetadataProvided_shouldCreateExpectedRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com";
    NSString *expectedNetworkHost = @"fakeauthority.net";
    NSString *expectedCacheHost = @"sts.fakeauthority.com";
    NSArray *expectedAliases = @[ expectedHost, expectedCacheHost, expectedNetworkHost ];
    NSArray *metadata = @[ @{ @"preferred_network" : expectedNetworkHost,
                              @"preferred_cache" :  expectedCacheHost,
                              @"aliases" : expectedAliases } ];
    
    NSError *error = nil;
    XCTAssertTrue([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    XCTAssertNil(error);
    // A record should be created for each of the aliases, and each of those records should be
    // identical
    MSIDAadAuthorityCacheRecord *record = [cache objectForKey:expectedHost];
    XCTAssertNotNil(record);
    XCTAssertEqualObjects(expectedNetworkHost, record.networkHost);
    XCTAssertEqualObjects(expectedCacheHost, record.cacheHost);
    XCTAssertEqualObjects(expectedAliases, record.aliases);
    record = [cache objectForKey:expectedNetworkHost];
    XCTAssertNotNil(record);
    XCTAssertEqualObjects(expectedNetworkHost, record.networkHost);
    XCTAssertEqualObjects(expectedCacheHost, record.cacheHost);
    XCTAssertEqualObjects(expectedAliases, record.aliases);
    record = [cache objectForKey:expectedCacheHost];
    XCTAssertNotNil(record);
    XCTAssertEqualObjects(expectedNetworkHost, record.networkHost);
    XCTAssertEqualObjects(expectedCacheHost, record.cacheHost);
    XCTAssertEqualObjects(expectedAliases, record.aliases);
}

- (void)testProcessMetadata_whenMetadataProvidedUsingAuthorityWithPort_shouldCreateExpectedRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com:443/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com";
    NSArray *metadata = @[ @{ @"preferred_network" : expectedHost,
                              @"preferred_cache" :  expectedHost,
                              @"aliases" : @[ expectedHost ] } ];
    
    NSError *error = nil;
    XCTAssertTrue([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    XCTAssertNil(error);
    // A record should be created for each of the aliases, and each of those records should be
    // identical
    MSIDAadAuthorityCacheRecord *record = [cache objectForKey:expectedHost];
    XCTAssertNotNil(record);
    XCTAssertEqualObjects(expectedHost, record.networkHost);
    XCTAssertEqualObjects(expectedHost, record.cacheHost);
    XCTAssertEqualObjects(@[ expectedHost ], record.aliases);
}

- (void)testProcessMetadata_whenMetadataProvidedWithNonStandardPortUsingAuthorityWithNonStandardPort_shouldCreateExpectedRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com:444/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com:444";
    NSArray *metadata = @[ @{ @"preferred_network" : expectedHost,
                              @"preferred_cache" :  expectedHost,
                              @"aliases" : @[ expectedHost ] } ];
    
    NSError *error = nil;
    XCTAssertTrue([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    XCTAssertNil(error);
    // A record should be created for each of the aliases, and each of those records should be
    // identical
    MSIDAadAuthorityCacheRecord *record = [cache objectForKey:expectedHost];
    XCTAssertNotNil(record);
    XCTAssertEqualObjects(expectedHost, record.networkHost);
    XCTAssertEqualObjects(expectedHost, record.cacheHost);
    XCTAssertEqualObjects(@[ expectedHost ], record.aliases);
}

- (void)testProcessMetadata_whenBadMetadataWrongNetworkHostType_shouldReturnErrorCreateNoRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com";
    NSString *expectedNetworkHost = @"fakeauthority.net";
    NSString *expectedCacheHost = @"sts.fakeauthority.com";
    NSArray *expectedAliases = @[ expectedHost, expectedCacheHost, expectedNetworkHost ];
    NSArray *metadata = @[ @{ @"preferred_network" : @1,
                              @"preferred_cache" :  expectedCacheHost,
                              @"aliases" : expectedAliases } ];
    
    NSError *error = nil;
    XCTAssertFalse([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    
    // Verify the correct error code is returned and no records were added to the cache
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
//    XCTAssertEqual(cache.recordMap.count, 0);
}

- (void)testProcessMetadata_whenBadMetadataWrongCacheHostType_shouldReturnErrorCreateNoRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com";
    NSString *expectedNetworkHost = @"fakeauthority.net";
    NSString *expectedCacheHost = @"sts.fakeauthority.com";
    NSArray *expectedAliases = @[ expectedHost, expectedCacheHost, expectedNetworkHost ];
    NSArray *metadata = @[ @{ @"preferred_network" : expectedNetworkHost,
                              @"preferred_cache" :  @1,
                              @"aliases" : expectedAliases } ];
    
    NSError *error = nil;
    XCTAssertFalse([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    
    // Verify the correct error code is returned and no records were added to the cache
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
//    XCTAssertEqual(cache.recordMap.count, 0);
}

- (void)testProcessMetadata_whenBadMetadataWrongAliasesType_shouldReturnErrorCreateNoRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSString *expectedNetworkHost = @"fakeauthority.net";
    NSString *expectedCacheHost = @"sts.fakeauthority.com";
    NSArray *metadata = @[ @{ @"preferred_network" : expectedNetworkHost,
                              @"preferred_cache" :  expectedCacheHost,
                              @"aliases" : @1 } ];
    
    NSError *error = nil;
    XCTAssertFalse([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    
    // Verify the correct error code is returned and no records were added to the cache
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
//    XCTAssertEqual(cache.recordMap.count, 0);
}

- (void)testProcessMetadata_whenBadMetadataWrongTypeInAliases_shouldReturnErrorCreateNoRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com";
    NSString *expectedNetworkHost = @"fakeauthority.net";
    NSString *expectedCacheHost = @"sts.fakeauthority.com";
    NSArray *expectedAliases = @[ expectedHost, @1, expectedNetworkHost ];
    NSArray *metadata = @[ @{ @"preferred_network" : expectedNetworkHost,
                              @"preferred_cache" :  expectedCacheHost,
                              @"aliases" : expectedAliases } ];
    
    NSError *error = nil;
    XCTAssertFalse([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    
    // Verify the correct error code is returned and no records were added to the cache
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
//    XCTAssertEqual(cache.recordMap.count, 0);
}

- (void)testProcessMetadata_whenInvalidHostInPreferredNetwork_shouldReturnErrorCreateNoRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com";
    NSString *expectedNetworkHost = @"fakeauthority.net";
    NSString *expectedCacheHost = @"sts.fakeauthority.com";
    NSArray *expectedAliases = @[ expectedHost, expectedNetworkHost, expectedCacheHost ];
    NSArray *metadata = @[ @{ @"preferred_network" : @"bad920354@#%$90-213423!!!:43",
                              @"preferred_cache" :  expectedCacheHost,
                              @"aliases" : expectedAliases } ];
    
    NSError *error = nil;
    XCTAssertFalse([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    
    // Verify the correct error code is returned and no records were added to the cache
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
//    XCTAssertEqual(cache.recordMap.count, 0);
}

- (void)testProcessMetadata_whenInvalidHostInPreferredCache_shouldReturnErrorCreateNoRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com";
    NSString *expectedNetworkHost = @"fakeauthority.net";
    NSString *expectedCacheHost = @"sts.fakeauthority.com";
    NSArray *expectedAliases = @[ expectedHost, expectedNetworkHost, expectedCacheHost ];
    NSArray *metadata = @[ @{ @"preferred_network" : expectedNetworkHost,
                              @"preferred_cache" :  @"bad920354@#%$90-213423!!!:43",
                              @"aliases" : expectedAliases } ];
    
    NSError *error = nil;
    XCTAssertFalse([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    
    // Verify the correct error code is returned and no records were added to the cache
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
//    XCTAssertEqual(cache.recordMap.count, 0);
}

- (void)testProcessMetadata_whenInvalidHostInAliases_shouldReturnErrorCreateNoRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com";
    NSString *expectedNetworkHost = @"fakeauthority.net";
    NSString *expectedCacheHost = @"sts.fakeauthority.com";
    NSArray *expectedAliases = @[ expectedHost, expectedNetworkHost, expectedCacheHost, @"bad920354@#%$90-213423!!!:43" ];
    NSArray *metadata = @[ @{ @"preferred_network" : expectedNetworkHost,
                              @"preferred_cache" :  expectedCacheHost,
                              @"aliases" : expectedAliases } ];
    
    NSError *error = nil;
    XCTAssertFalse([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    
    // Verify the correct error code is returned and no records were added to the cache
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
//    XCTAssertEqual(cache.recordMap.count, 0);
}

- (void)testProcessMetadata_whenInvalidPortInPreferredNetwork_shouldReturnErrorCreateNoRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com";
    NSString *expectedNetworkHost = @"fakeauthority.net";
    NSString *expectedCacheHost = @"sts.fakeauthority.com";
    NSArray *expectedAliases = @[ expectedHost, expectedNetworkHost, expectedCacheHost ];
    NSArray *metadata = @[ @{ @"preferred_network" : @"sts.contoso.com:4sde3as",
                              @"preferred_cache" :  expectedCacheHost,
                              @"aliases" : expectedAliases } ];
    
    NSError *error = nil;
    XCTAssertFalse([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    
    // Verify the correct error code is returned and no records were added to the cache
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
//    XCTAssertEqual(cache.recordMap.count, 0);
}

- (void)testProcessMetadata_whenInvalidPortInPreferredCache_shouldReturnErrorCreateNoRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com";
    NSString *expectedNetworkHost = @"fakeauthority.net";
    NSString *expectedCacheHost = @"sts.fakeauthority.com";
    NSArray *expectedAliases = @[ expectedHost, expectedNetworkHost, expectedCacheHost ];
    NSArray *metadata = @[ @{ @"preferred_network" : expectedNetworkHost,
                              @"preferred_cache" :  @"sts.contoso.com:43as",
                              @"aliases" : expectedAliases } ];
    
    NSError *error = nil;
    XCTAssertFalse([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    
    // Verify the correct error code is returned and no records were added to the cache
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
//    XCTAssertEqual(cache.recordMap.count, 0);
}

- (void)testProcessMetadata_whenInvalidPortInAliases_shouldReturnErrorCreateNoRecords
{
    MSIDAadAuthorityCache *cache = [[MSIDAadAuthorityCache alloc] init];
    NSURL *authority = [NSURL URLWithString:@"https://fakeauthority.com/v2/oauth/endpoint"];
    NSString *expectedHost = @"fakeauthority.com";
    NSString *expectedNetworkHost = @"fakeauthority.net";
    NSString *expectedCacheHost = @"sts.fakeauthority.com";
    NSArray *expectedAliases = @[ expectedHost, expectedNetworkHost, expectedCacheHost, @"sts.contoso.com:43as" ];
    NSArray *metadata = @[ @{ @"preferred_network" : expectedNetworkHost,
                              @"preferred_cache" :  expectedCacheHost,
                              @"aliases" : expectedAliases } ];
    
    NSError *error = nil;
    XCTAssertFalse([cache processMetadata:metadata openIdConfigEndpoint:nil authority:authority context:nil error:&error]);
    
    
    // Verify the correct error code is returned and no records were added to the cache
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorServerInvalidResponse);
//    XCTAssertEqual(cache.recordMap.count, 0);
}

@end

