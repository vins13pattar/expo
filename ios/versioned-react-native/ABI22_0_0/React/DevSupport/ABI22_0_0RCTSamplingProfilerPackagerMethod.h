/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <ReactABI22_0_0/ABI22_0_0RCTPackagerClient.h>

@protocol ABI22_0_0RCTJSEnvironment;

#if ABI22_0_0RCT_DEV // Only supported in dev mode

@interface ABI22_0_0RCTSamplingProfilerPackagerMethod : NSObject <ABI22_0_0RCTPackagerClientMethod>

- (instancetype)initWithJSEnvironment:(id<ABI22_0_0RCTJSEnvironment>)jsEnvironment;

@end

#endif
