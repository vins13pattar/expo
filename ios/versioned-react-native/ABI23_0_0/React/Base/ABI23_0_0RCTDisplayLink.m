/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI23_0_0RCTDisplayLink.h"

#import <Foundation/Foundation.h>
#import <QuartzCore/CADisplayLink.h>

#import "ABI23_0_0RCTAssert.h"
#import "ABI23_0_0RCTBridgeModule.h"
#import "ABI23_0_0RCTFrameUpdate.h"
#import "ABI23_0_0RCTModuleData.h"
#import "ABI23_0_0RCTProfile.h"

#define ABI23_0_0RCTAssertRunLoop() \
  ABI23_0_0RCTAssert(_runLoop == [NSRunLoop currentRunLoop], \
  @"This method must be called on the CADisplayLink run loop")

@implementation ABI23_0_0RCTDisplayLink
{
  CADisplayLink *_jsDisplayLink;
  NSMutableSet<ABI23_0_0RCTModuleData *> *_frameUpdateObservers;
  NSRunLoop *_runLoop;
}

- (instancetype)init
{
  if ((self = [super init])) {
    _frameUpdateObservers = [NSMutableSet new];
    _jsDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_jsThreadUpdate:)];
  }

  return self;
}

- (void)registerModuleForFrameUpdates:(id<ABI23_0_0RCTBridgeModule>)module
                       withModuleData:(ABI23_0_0RCTModuleData *)moduleData
{
  if (![moduleData.moduleClass conformsToProtocol:@protocol(ABI23_0_0RCTFrameUpdateObserver)] ||
      [_frameUpdateObservers containsObject:moduleData]) {
    return;
  }

  [_frameUpdateObservers addObject:moduleData];

  // Don't access the module instance via moduleData, as this will cause deadlock
  id<ABI23_0_0RCTFrameUpdateObserver> observer = (id<ABI23_0_0RCTFrameUpdateObserver>)module;
  __weak typeof(self) weakSelf = self;
  observer.pauseCallback = ^{
    typeof(self) strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }

    CFRunLoopRef cfRunLoop = [strongSelf->_runLoop getCFRunLoop];
    if (!cfRunLoop) {
      return;
    }

    if ([NSRunLoop currentRunLoop] == strongSelf->_runLoop) {
      [weakSelf updateJSDisplayLinkState];
    } else {
      CFRunLoopPerformBlock(cfRunLoop, kCFRunLoopDefaultMode, ^{
        [weakSelf updateJSDisplayLinkState];
      });
      CFRunLoopWakeUp(cfRunLoop);
    }
  };

  // Assuming we're paused right now, we only need to update the display link's state
  // when the new observer is not paused. If it not paused, the observer will immediately
  // start receiving updates anyway.
  if (![observer isPaused] && _runLoop) {
    CFRunLoopPerformBlock([_runLoop getCFRunLoop], kCFRunLoopDefaultMode, ^{
      [self updateJSDisplayLinkState];
    });
  }
}

- (void)addToRunLoop:(NSRunLoop *)runLoop
{
  _runLoop = runLoop;
  [_jsDisplayLink addToRunLoop:runLoop forMode:NSRunLoopCommonModes];
}

- (void)invalidate
{
  [_jsDisplayLink invalidate];
}

- (void)dispatchBlock:(dispatch_block_t)block
                queue:(dispatch_queue_t)queue
{
  if (queue == ABI23_0_0RCTJSThread) {
    block();
  } else if (queue) {
    dispatch_async(queue, block);
  }
}

- (void)_jsThreadUpdate:(CADisplayLink *)displayLink
{
  ABI23_0_0RCTAssertRunLoop();

  ABI23_0_0RCT_PROFILE_BEGIN_EVENT(ABI23_0_0RCTProfileTagAlways, @"-[ABI23_0_0RCTDisplayLink _jsThreadUpdate:]", nil);

  ABI23_0_0RCTFrameUpdate *frameUpdate = [[ABI23_0_0RCTFrameUpdate alloc] initWithDisplayLink:displayLink];
  for (ABI23_0_0RCTModuleData *moduleData in _frameUpdateObservers) {
    id<ABI23_0_0RCTFrameUpdateObserver> observer = (id<ABI23_0_0RCTFrameUpdateObserver>)moduleData.instance;
    if (!observer.paused) {
      ABI23_0_0RCTProfileBeginFlowEvent();

      [self dispatchBlock:^{
        ABI23_0_0RCTProfileEndFlowEvent();
        [observer didUpdateFrame:frameUpdate];
      } queue:moduleData.methodQueue];
    }
  }

  [self updateJSDisplayLinkState];

  ABI23_0_0RCTProfileImmediateEvent(ABI23_0_0RCTProfileTagAlways, @"JS Thread Tick", displayLink.timestamp, 'g');

  ABI23_0_0RCT_PROFILE_END_EVENT(ABI23_0_0RCTProfileTagAlways, @"objc_call");
}

- (void)updateJSDisplayLinkState
{
  ABI23_0_0RCTAssertRunLoop();

  BOOL pauseDisplayLink = YES;
  for (ABI23_0_0RCTModuleData *moduleData in _frameUpdateObservers) {
    id<ABI23_0_0RCTFrameUpdateObserver> observer = (id<ABI23_0_0RCTFrameUpdateObserver>)moduleData.instance;
    if (!observer.paused) {
      pauseDisplayLink = NO;
      break;
    }
  }

  _jsDisplayLink.paused = pauseDisplayLink;
}

@end
