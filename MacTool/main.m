/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A Mac command line tool to test the SimplePing class.
 */

#import "SimplePing.h"

#include <sys/socket.h>
#include <netdb.h>

#pragma mark * Utilities

/*! Returns the string representation of the supplied address.
 *  \param address Contains a (struct sockaddr) with the address to render.
 *  \returns A string representation of that address.
 */

static NSString * displayAddressForAddress(NSData * address) {
    int         err;
    NSString *  result;
    char        hostStr[NI_MAXHOST];
    
    result = nil;
    
    if (address != nil) {
        err = getnameinfo(address.bytes, (socklen_t) address.length, hostStr, sizeof(hostStr), NULL, 0, NI_NUMERICHOST);
        if (err == 0) {
            result = @(hostStr);
        }
    }
    
    if (result == nil) {
        result = @"?";
    }

    return result;
}

/*! Returns a short error string for the supplied error.
 *  \param error The error to render.
 *  \returns A short string representing that error.
 */

static NSString * shortErrorFromError(NSError * error) {
    NSString *      result;
    NSNumber *      failureNum;
    int             failure;
    const char *    failureStr;
    
    assert(error != nil);
    
    result = nil;
    
    // Handle DNS errors as a special case.
    
    if ( [error.domain isEqual:(NSString *)kCFErrorDomainCFNetwork] && (error.code == kCFHostErrorUnknown) ) {
        failureNum = error.userInfo[(id) kCFGetAddrInfoFailureKey];
        if ( [failureNum isKindOfClass:[NSNumber class]] ) {
            failure = failureNum.intValue;
            if (failure != 0) {
                failureStr = gai_strerror(failure);
                if (failureStr != NULL) {
                    result = @(failureStr);
                }
            }
        }
    }
    
    // Otherwise try various properties of the error object.
    
    if (result == nil) {
        result = error.localizedFailureReason;
    }
    if (result == nil) {
        result = error.localizedDescription;
    }
    assert(result != nil);
    return result;
}


#pragma mark * Main

/*! The main object for our tool.
 *  \details This exists primarily because SimplePing requires an object to act as its delegate.
 */

@interface Main : NSObject <SimplePingDelegate>

@property (nonatomic, assign, readwrite) BOOL                   forceIPv4;
@property (nonatomic, assign, readwrite) BOOL                   forceIPv6;
@property (nonatomic, strong, readwrite, nullable) SimplePing * pinger;
@property (nonatomic, strong, readwrite, nullable) NSTimer *    sendTimer;

@end

@implementation Main

- (void)dealloc {
    [self->_pinger stop];
    [self->_sendTimer invalidate];
}

/*! The Objective-C 'main' for this program.
 *  \details This creates a SimplePing object, configures it, and then runs the run loop 
 *      sending pings and printing the results.
 *  \param hostName The host to ping.
 */

- (void)runWithHostName:(NSString *)hostName {
    assert(self.pinger == nil);
    
    self.pinger = [[SimplePing alloc] initWithHostName:hostName];
    assert(self.pinger != nil);
    
    // By default we use the first IP address we get back from host resolution (.Any) 
    // but these flags let the user override that.
        
    if (self.forceIPv4 && ! self.forceIPv6) {
        self.pinger.addressStyle = SimplePingAddressStyleICMPv4;
    } else if (self.forceIPv6 && ! self.forceIPv4) {
        self.pinger.addressStyle = SimplePingAddressStyleICMPv6;
    }
    
    self.pinger.delegate = self;
    [self.pinger start];
    
    do {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    } while (self.pinger != nil);
}

/*! Sends a ping.
 *  \details Called to send a ping, both directly (as soon as the SimplePing object starts up) 
 *      and via a timer (to continue sending pings periodically).
 */

- (void)sendPing {
    assert(self.pinger != nil);
    [self.pinger sendPingWithData:nil];
}

- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {
    #pragma unused(pinger)
    assert(pinger == self.pinger);
    assert(address != nil);

    NSLog(@"pinging %@", displayAddressForAddress(address));

    // Send the first ping straight away.
    
    [self sendPing];

    // And start a timer to send the subsequent pings.
    
    assert(self.sendTimer == nil);
    self.sendTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(sendPing) userInfo:nil repeats:YES];
}

- (void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
    #pragma unused(pinger)
    assert(pinger == self.pinger);
    NSLog(@"failed: %@", shortErrorFromError(error));

    [self.sendTimer invalidate];
    self.sendTimer = nil;

    // No need to call -stop.  The pinger will stop itself in this case.
    // We do however want to nil out pinger so that the runloop stops.

    self.pinger = nil;
}

- (void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber {
    #pragma unused(pinger)
    assert(pinger == self.pinger);
    #pragma unused(packet)
    NSLog(@"#%u sent", (unsigned int) sequenceNumber);
}

- (void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error {
    #pragma unused(pinger)
    assert(pinger == self.pinger);
    #pragma unused(packet)
    NSLog(@"#%u send failed: %@", (unsigned int) sequenceNumber, shortErrorFromError(error));
}

- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber {
    #pragma unused(pinger)
    assert(pinger == self.pinger);
    #pragma unused(packet)
    NSLog(@"#%u received, size=%zu", (unsigned int) sequenceNumber, (size_t) packet.length);
}

- (void)simplePing:(SimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet {
    #pragma unused(pinger)
    assert(pinger == self.pinger);
    
    NSLog(@"unexpected packet, size=%zu", (size_t) packet.length);
}

@end

int main(int argc, char* argv[]) {
    int                 retVal;

    @autoreleasepool {
        int     ch;
        Main *  mainObj;

        mainObj = [[Main alloc] init];

        retVal = EXIT_SUCCESS;
        do {
            ch = getopt(argc, argv, "46");
            if (ch != -1) {
                switch (ch) {
                    case '4': {
                        mainObj.forceIPv4 = YES;
                    } break;
                    case '6': {
                        mainObj.forceIPv6 = YES;
                    } break;
                    case '?':
                    default: {
                        retVal = EXIT_FAILURE;
                    } break;
                }
            }
        } while ( (ch != -1) && (retVal == EXIT_SUCCESS) );

        if ( (retVal == EXIT_SUCCESS) && ((optind + 1) != argc) ) {
            retVal = EXIT_FAILURE;
        }

        if (retVal == EXIT_FAILURE) {
            fprintf(stderr, "usage: %s [-4] [-6] host\n", getprogname());
        } else {
            [mainObj runWithHostName:@(argv[optind])];
        }
    }

    return retVal;
}
