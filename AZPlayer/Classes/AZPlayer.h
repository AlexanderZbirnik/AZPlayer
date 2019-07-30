//
//  AZPlayer.h
//  AZPlayer
//
//  Created by Alex Zbirnik on 24.07.19.
//  Copyright © 2019 Alex Zbirnik. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AZPlayerDelegate;

@interface AZPlayer : NSObject

@property (weak, nonatomic) id <AZPlayerDelegate> delegate;

// Default volume 1.0
@property (assign, nonatomic) float volume;
@property (assign, nonatomic) float rate;

@property (assign, nonatomic, readonly) BOOL isPlayed;
@property (assign, nonatomic, readonly) NSInteger currentTime;
@property (assign, nonatomic, readonly) CMTime duration;


- (instancetype)initWithURL:(NSURL *)url;

- (void)play;
- (void)pause;
- (void)seekToSeconds:(NSInteger)seconds;
- (void)seekToTime:(CMTime)time;

@end

@protocol AZPlayerDelegate <NSObject>

@required

- (void)readyToPlay:(AZPlayer *)player;

@optional
// Change player status
- (void)failedPlayer:(AZPlayer *)player withError:(NSError *)error;
- (void)notReadyToPlay:(AZPlayer *)player;
- (void)play:(AZPlayer *)player withOutStalling:(BOOL)stalling;
- (void)bufferFull:(BOOL)full inPlayer:(AZPlayer *)player;
- (void)bufferEmpty:(BOOL)empty inPlayer:(AZPlayer *)player;
- (void)player:(AZPlayer *)player louddly:(BOOL)louddly power:(CGFloat)power;
// Current time in seconds
- (void)player:(AZPlayer *)player currentTime:(NSInteger)time;
- (void)playToEnd:(AZPlayer *)player;

@end

NS_ASSUME_NONNULL_END
