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

#import "MSIDJWTHelper.h"
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#import <Security/SecKey.h>
#import "NSString+MSIDExtensions.h"
#import "MSIDLogger+Internal.h"
#import "NSData+JWT.h"
#import "NSData+MSIDExtensions.h"

@implementation MSIDJWTHelper

static NSString *kEccSharedAccessGroup = @"SGGM6D27TK.com.microsoft.ecctest";
static NSString *kEccPrivateKeyTag = @"com.microsoft.eccprivatekey";

+ (NSString *)createSignedJWTforHeader:(NSDictionary *)header
                              payload:(NSDictionary *)payload
                           signingKey:(SecKeyRef)signingKey
{
    NSString *headerJSON = [self JSONFromDictionary:header];
    NSString *payloadJSON = [self JSONFromDictionary:payload];
    NSString *signingInput = [NSString stringWithFormat:@"%@.%@", [headerJSON msidBase64UrlEncode], [payloadJSON msidBase64UrlEncode]];
//    NSData *signedData = [self sign:signingKey
//                               data:[signingInput dataUsingEncoding:NSUTF8StringEncoding]];
    NSError *error;
    NSData *dataHashToBeSigned = [signingInput dataUsingEncoding:NSUTF8StringEncoding];
    NSData *signedData = [self eccSignData:[dataHashToBeSigned msidSHA256] signingError:&error];
    NSString *signedEncodedDataString = [NSString msidBase64UrlEncodedStringFromData:signedData];

    return [NSString stringWithFormat:@"%@.%@", signingInput, signedEncodedDataString];
}

+ (NSString *)decryptJWT:(NSData *)jwtData
           decryptionKey:(SecKeyRef)decryptionKey
{
#if TARGET_OS_IPHONE
    size_t cipherBufferSize = SecKeyGetBlockSize(decryptionKey);
#endif // TARGET_OS_IPHONE
    size_t keyBufferSize = [jwtData length];

    NSMutableData *bits = [NSMutableData dataWithLength:keyBufferSize];
    OSStatus status = errSecAuthFailed;
#if TARGET_OS_IPHONE
    status = SecKeyDecrypt(decryptionKey,
                           kSecPaddingPKCS1,
                           (const uint8_t *) [jwtData bytes],
                           cipherBufferSize,
                           [bits mutableBytes],
                           &keyBufferSize);
#else // !TARGET_OS_IPHONE
    (void)decryptionKey;
    // TODO: SecKeyDecrypt is not available on OS X
#endif // TARGET_OS_IPHONE
    if(status != errSecSuccess)
    {
        return nil;
    }

    [bits setLength:keyBufferSize];
    return [[NSString alloc] initWithData:bits encoding:NSUTF8StringEncoding];
}

+ (NSData *)sign:(SecKeyRef)privateKey
            data:(NSData *)plainData
{

    NSData *hashData = [plainData msidSHA256];
    return [hashData msidSignHashWithPrivateKey:privateKey];
}

+ (NSString *)JSONFromDictionary:(NSDictionary *)dictionary
{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (!jsonData)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Got an error code: %ld error: %@", (long)error.code, MSID_PII_LOG_MASKABLE(error));

        return nil;
    }

    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return json;
}

+(NSData *) eccSignData:(NSData *)signingInputHash signingError:(NSError **)error
{
    NSData *tag = [kEccPrivateKeyTag dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary * queryPrivateKey = [[NSMutableDictionary alloc] init];
    CFErrorRef signingError = NULL;
    
    // Set the private key query dictionary.
    [queryPrivateKey setObject:(__bridge id)kSecClassKey forKey:(__bridge id)kSecClass];
    [queryPrivateKey setObject:tag forKey:(__bridge id)kSecAttrApplicationTag];
    [queryPrivateKey setObject:(__bridge id)kSecAttrKeyTypeEC forKey:(__bridge id)kSecAttrKeyType];
    [queryPrivateKey setObject:[NSNumber numberWithBool:YES] forKey:(__bridge id)kSecReturnRef];
    [queryPrivateKey setObject:kEccSharedAccessGroup forKey:(__bridge id)kSecAttrAccessGroup];
#if !TARGET_OS_IPHONE
    if (@available(macOS 10.15, *)) {
        [queryPrivateKey setObject:@YES forKey:(id)kSecUseDataProtectionKeychain];
    } else {
        // Fallback on earlier versions
    };
#endif
    OSStatus status= noErr;
    SecKeyRef privateKeyReference = NULL;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)queryPrivateKey, (CFTypeRef *)&privateKeyReference);
    
    if (status != errSecSuccess)
    {
        privateKeyReference = nil;
        if (error)
        *error = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
    
    if (privateKeyReference == NULL)
        return nil;
    
    NSData *ecSignature = (NSData *)CFBridgingRelease(SecKeyCreateSignature(privateKeyReference,
                                                                    kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                                                    (__bridge CFDataRef)signingInputHash,
                                                                    &signingError));
    if (!ecSignature)
    {
        *error = CFBridgingRelease(signingError);
    }
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKeyReference);
    NSData *publicKeyBits = CFBridgingRelease(SecKeyCopyExternalRepresentation(publicKey, &signingError));
    NSString *publicKeyBase64Url = [NSString msidBase64UrlEncodedStringFromData:publicKeyBits];
    NSString *baseEncoded = [NSString msidBase64UrlEncodedStringFromData:publicKeyBits];
    BOOL isVerified = SecKeyVerifySignature(publicKey,kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                                                    (__bridge CFDataRef) signingInputHash,
                                                                    (__bridge CFDataRef) ecSignature,
                                                                    &signingError);
    if (isVerified && publicKeyBits && baseEncoded && publicKeyBase64Url)
    {
    
    }
    return ecSignature;
}

@end
