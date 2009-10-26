//
//  AccountManager.m
//  Tweetero
//
//  Created by Sergey Shkrabak on 9/15/09.
//  Copyright 2009 Codeminders. All rights reserved.
//

#import "AccountManager.h"
#import "MGTwitterEngine.h"
#import "UserAccount.h"

#define ACCOUNT_MANAGER_KEY             @"Accounts"
#define ACCOUNT_MANAGER_LAST_USER_KEY   @"AccountLastUser"
#define SEC_ATTR_SERVER                 @"twitter.com"

@interface AccountManager(Private)
- (NSMutableDictionary *)prepareSecItemEntry:(NSString *)server user:(NSString *)userName;
- (void)updateStandadUserDefaults;
- (void)updateLoggedUserAccount:(UserAccount*)account;
- (void)loadSavedAccounts;
- (BOOL)validateAccount:(UserAccount*)account;
@end

@implementation AccountManager

@synthesize loggedUserAccount = _loggedUserAccount;

+ (AccountManager*)manager
{
    static AccountManager *manager = nil;
    
    if (manager == nil)
        manager = [[AccountManager alloc] init];
    return manager;
}

- (id)init
{
    if (self = [super init])
    {
        _accounts = [[NSMutableDictionary alloc] init];
        _loggedUserAccount = nil;
        [self loadSavedAccounts];
    }
    return self;
}

- (void)dealloc
{
    [self clearLoggedObject];
    [_accounts release];
    [super dealloc];
}

- (void)saveAccount:(UserAccount*)account
{
    NSLog(@"Save account method");
    if (account == nil)
        return;
    
    BOOL isNewAccount = ![self hasAccountWithUsername:account.username];
    BOOL isValid = [self validateAccount:account];
    
    NSLog(@"Account present = %i", isNewAccount);
    if (isNewAccount && isValid)
    {
        // Add and save new account
        NSString *securityString = nil;
        
        if ([account authType] == TwitterCommon)
            securityString = ((TwitterCommonUserAccount*)account).password;
        
        NSData *secData = [securityString dataUsingEncoding:NSUTF8StringEncoding];

        // Prepate SecItemEnty
        NSMutableDictionary *secItemEntry = [self prepareSecItemEntry:SEC_ATTR_SERVER user:account.username];
        [secItemEntry setObject:secData forKey:(id)kSecValueData];
        
        OSStatus err = SecItemAdd((CFDictionaryRef)secItemEntry, NULL);
        
        NSLog(@"SecItemAdd result = %i (noErr = %i)", err, noErr);
        if (err == noErr)
        {
            // Add account to dictionary
            [_accounts setObject:account forKey:account.username];
            
            // Update user defaults
            [self updateStandadUserDefaults];
        }
    }
}

- (void)replaceAccount:(UserAccount*)oldAccount with:(UserAccount*)newAccount
{
    NSLog(@"Replace account method");
    if (oldAccount == nil || newAccount == nil)
        return;
    
    BOOL hasOldAccount = [self hasAccountWithUsername:oldAccount.username];
    BOOL hasNewAccount = [self hasAccountWithUsername:newAccount.username];
    
    NSLog(@"Has oldAccount = %i, has newAccount = %i", hasOldAccount, hasNewAccount);
    if (hasOldAccount)
    {
        BOOL isValid = [self validateAccount:newAccount];
        if (!isValid)
            return;
        
        // Replace user data
        if ([oldAccount.username compare:newAccount.username] == NSOrderedSame)
        {
            NSLog(@"Replace security data");
            
            NSString *secString = nil;
            
            if ([newAccount authType] == TwitterCommon)
                secString = ((TwitterCommonUserAccount*)newAccount).password;
            
            NSMutableDictionary *secItemEntry = [self prepareSecItemEntry:SEC_ATTR_SERVER user:oldAccount.username];
            
            NSData *secData = [secString dataUsingEncoding:NSUTF8StringEncoding];
            NSMutableDictionary *attrToUpdate = [[NSMutableDictionary alloc] init];
            
            [attrToUpdate setObject:secData forKey:(id)kSecValueData];
            
            OSStatus err = SecItemUpdate((CFDictionaryRef)secItemEntry, (CFDictionaryRef)attrToUpdate);
            
            NSLog(@"SecItemAdd result = %i (noErr = %i)", err, noErr);
            if (err == noErr)
            {
                // Update accounts dictionary
                [_accounts removeObjectForKey:oldAccount.username];
                [_accounts setObject:newAccount forKey:newAccount.username];
                
                // Update app defauls
                [self updateStandadUserDefaults];
            }
            
            [attrToUpdate release];            
        }
        else if (!hasNewAccount)
        {
            NSLog(@"Remove old and add new accounts");
            // Delete old account
            [self removeAccount:oldAccount];
            // Add new account
            [self saveAccount:newAccount];
        }
    }
}

- (void)removeAccount:(UserAccount*)account
{
    NSLog(@"Reemove account method");
    BOOL hasAccount = [self hasAccountWithUsername:account.username];
    
    NSLog(@"Account present = %i", hasAccount);
    if (hasAccount)
    {
        NSMutableDictionary *secItemEntry = [self prepareSecItemEntry:SEC_ATTR_SERVER user:account.username];
        
        // Remove data from KeyChain
        OSStatus err = SecItemDelete((CFDictionaryRef)secItemEntry);
        
        NSLog(@"SecItemAdd result = %i (noErr = %i)", err, noErr);
        if (err == noErr)
        {
            // Remove account from dictionary
            [_accounts removeObjectForKey:account.username];
            
            // Update app defaults
            [self updateStandadUserDefaults];
        }
    }
}

- (UserAccount*)accountByUsername:(NSString*)username
{
    return [[[_accounts objectForKey:username] retain] autorelease];
}

- (NSArray*)allAccountUsername
{
    return [NSArray arrayWithArray:[_accounts allKeys]];
}

- (BOOL)hasAccountWithUsername:(NSString*)username
{
    return !([self accountByUsername:username] == nil);
}

- (void)login:(UserAccount*)account
{
    if (account)
    {
        TwitterCommonUserAccount *commonAccount = (TwitterCommonUserAccount*)account;
        
        [MGTwitterEngine setUsername:commonAccount.username password:commonAccount.password remember:NO];
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:commonAccount.username, @"login", commonAccount.password, @"password", nil];
        [[NSNotificationCenter defaultCenter] postNotificationName: @"AccountChanged" 
                                                            object: nil
                                                          userInfo: userInfo];
        if ([MGTwitterEngine username] != nil && [MGTwitterEngine password] != nil)
            [self updateLoggedUserAccount:commonAccount];
    }
}

- (void)clearLoggedObject
{
    if (_loggedUserAccount)
        [_loggedUserAccount release];
}

@end

@implementation AccountManager(Private)

- (NSMutableDictionary *)prepareSecItemEntry:(NSString *)server user:(NSString *)userName
{
    NSMutableDictionary *secItemEntry = [[NSMutableDictionary alloc] init];
    
    [secItemEntry setObject:(id)kSecClassInternetPassword forKey:(id)kSecClass];
    [secItemEntry setObject:server forKey:(id)kSecAttrServer];
    [secItemEntry setObject:userName forKey:(id)kSecAttrAccount];
    return [secItemEntry autorelease];
}

- (void)updateStandadUserDefaults
{
    NSArray *usernames = [self allAccountUsername];
    
    [[NSUserDefaults standardUserDefaults] setObject:usernames forKey:ACCOUNT_MANAGER_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)updateLoggedUserAccount:(UserAccount*)account
{
    [self clearLoggedObject];
    
    _loggedUserAccount = [account retain];
    
    [[NSUserDefaults standardUserDefaults] setObject:account.username forKey:ACCOUNT_MANAGER_LAST_USER_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadSavedAccounts
{
    NSArray *accounts = [[NSUserDefaults standardUserDefaults] arrayForKey:ACCOUNT_MANAGER_KEY];
    
    // Load all account data
    for (NSString *username in accounts)
    {
        NSMutableDictionary *secItemEntry = [self prepareSecItemEntry:SEC_ATTR_SERVER user:username];
        
        [secItemEntry setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
        [secItemEntry setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
        
        NSData *result = nil;
        OSStatus err = SecItemCopyMatching((CFDictionaryRef)secItemEntry, (CFTypeRef*)&result);
        
        NSString *secData = nil;
        if (err == noErr && result)
        {
            secData = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
            
            TwitterCommonUserAccount *account = [[TwitterCommonUserAccount alloc] init];
            account.username = username;
            account.password = secData;
            
            [_accounts setObject:account forKey:account.username];
            
            [account release];
            [secData release];
        }
    }
    
    NSString *lastAccountUsername = [[NSUserDefaults standardUserDefaults] stringForKey:ACCOUNT_MANAGER_LAST_USER_KEY];
    
    UserAccount *lastAccount = [self accountByUsername:lastAccountUsername];
    [self login:lastAccount];
}

- (BOOL)validateAccount:(UserAccount*)account
{
    if (!account)
        return NO;
    
    BOOL valid = NO;
    
    
    valid = ([account.username length] > 0);
    
    return valid;
}

@end