//
//  AZPlayer.m
//  AZPlayer
//
//  Created by Alex Zbirnik on 24.07.19.
//  Copyright © 2019 Alex Zbirnik. All rights reserved.
//

#import "AZPlayer.h"
#import <Accelerate/Accelerate.h>

static NSString * const AZPlayerKeyPathStatus = @"status";
static NSString * const AZPlayerKeyPathPlaybackLikely = @"playbackLikelyToKeepUp";
static NSString * const AZPlayerKeyPathBufferFull = @"playbackBufferFull";
static NSString * const AZPlayerKeyPathBufferEmpty = @"playbackBufferEmpty";

@interface AZPlayer ()

@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVAsset *asset;
@property (strong, nonatomic) id timeObserverToken;
@property (strong, nonatomic) id playToEndNotificationToken;

@end

@implementation AZPlayer

#pragma mark - Object lifecycle

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        self.volume = 1.0;
        self.rate = 1.0;
        self.asset = [AVAsset assetWithURL:url];
        AVPlayerItem *item = [[AVPlayerItem alloc] initWithAsset:self.asset];
        self.player = [[AVPlayer alloc] initWithPlayerItem:item];
        self.player.automaticallyWaitsToMinimizeStalling = NO;
    }
    return self;
}

- (void)dealloc {
    [self removeObservers];
    [self removeNotifications];
}

- (void)setDelegate:(id<AZPlayerDelegate>)delegate {
    _delegate = delegate;
    [self addObserversForItem:self.player.currentItem];
    [self addPeriodicTimeObserver];
    [self addNotificationsForItem:self.player.currentItem];
}

- (void)setRate:(float)rate {
    _rate = rate;
    if (_isPlayed) {
        _player.rate = _rate;
    }
}

- (CMTime)duration {
    return self.player.currentItem.asset.duration;
}

#pragma mark - Player

- (void)play {
    self.player.currentItem.audioMix = [self mixAsset:self.asset];
    [self.player playImmediatelyAtRate:self.rate];
    _isPlayed = YES;
}

- (void)pause {
    [self.player pause];
    self.player.currentItem.audioMix = NULL;
    _isPlayed = NO;
}

- (void)seekToSeconds:(NSInteger)seconds {
    CMTime time = CMTimeMake(seconds, 1);
    [self seekToTime:time];
}

- (void)seekToSeconds:(NSInteger)seconds completionHandler:(void (^)(BOOL finished))completionHandler {
    CMTime time = CMTimeMake(seconds, 1);
    [self seekToTime:time completionHandler:completionHandler];
}

- (void)seekToTime:(CMTime)time {
    [self.player.currentItem cancelPendingSeeks];
    if (self.isPlayed) {
        [self.player pause];
        [self.player seekToTime:time];
        [self.player playImmediatelyAtRate:self.rate];
        return;
    }
    [self.player seekToTime:time];
}

- (void)seekToTime:(CMTime)time completionHandler:(void (^)(BOOL finished))completionHandler {
    [self.player.currentItem cancelPendingSeeks];
    if (self.isPlayed) {
        [self.player pause];
        [self.player seekToTime:time];
        [self.player playImmediatelyAtRate:self.rate];
        return;
    }
    [self.player seekToTime:time completionHandler:completionHandler];
}

#pragma mark - Processing audio

- (AVMutableAudioMix *)mixAsset:(AVAsset *)asset {
    // Continuing on from where we created the AVAsset...
    AVAssetTrack *audioTrack = [[asset tracks] objectAtIndex:0];
    AVMutableAudioMixInputParameters *inputParams = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioTrack];
    
    // Create a processing tap for the input parameters
    MTAudioProcessingTapCallbacks callbacks;
    callbacks.version = kMTAudioProcessingTapCallbacksVersion_0;
    callbacks.clientInfo = (__bridge void *)(self);
    callbacks.init = init;
    callbacks.prepare = prepare;
    callbacks.process = process;
    callbacks.unprepare = unprepare;
    callbacks.finalize = finalize;
    
    MTAudioProcessingTapRef tap;
    // The create function makes a copy of our callbacks struct
    OSStatus err = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks,
                                              kMTAudioProcessingTapCreationFlag_PostEffects, &tap);
    if (err || !tap) {
        NSLog(@"Unable to create the Audio Processing Tap");
        return NULL;
    }
    assert(tap);
    
    // Assign the tap to the input parameters
    inputParams.audioTapProcessor = tap;
    
    // Create a new AVAudioMix and assign it to our AVPlayerItem
    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    audioMix.inputParameters = @[inputParams];
    
    return audioMix;
}

void init(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut) {
    NSLog(@"Initialising the Audio Tap Processor");
    *tapStorageOut = clientInfo;
}

void finalize(MTAudioProcessingTapRef tap) {
    NSLog(@"Finalizing the Audio Tap Processor");
}

void prepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat) {
    NSLog(@"Preparing the Audio Tap Processor");
}

void unprepare(MTAudioProcessingTapRef tap) {
    NSLog(@"Unpreparing the Audio Tap Processor");
}

void process(MTAudioProcessingTapRef tap, CMItemCount numberFrames,
             MTAudioProcessingTapFlags flags, AudioBufferList *bufferListInOut,
             CMItemCount *numberFramesOut, MTAudioProcessingTapFlags *flagsOut) {
    
    OSStatus err = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut,
                                                      flagsOut, NULL, numberFramesOut);
    if (err) NSLog(@"Error from GetSourceAudio: %d", (int)err);
    
    AZPlayer *self = (__bridge AZPlayer *) MTAudioProcessingTapGetStorage(tap);
    
    [self changeVolume:bufferListInOut];
    [self calculateSoundPower:bufferListInOut numberFrames:numberFrames];
}

- (void)changeVolume:(AudioBufferList *)bufferListInOut {
    float volume = self.volume;
    vDSP_vsmul(bufferListInOut->mBuffers[1].mData, 1, &volume, bufferListInOut->mBuffers[1].mData, 1, bufferListInOut->mBuffers[1].mDataByteSize / sizeof(float));
    vDSP_vsmul(bufferListInOut->mBuffers[0].mData, 1, &volume, bufferListInOut->mBuffers[0].mData, 1, bufferListInOut->mBuffers[0].mDataByteSize / sizeof(float));
}

- (void)calculateSoundPower:(AudioBufferList *)bufferListInOut numberFrames:(CMItemCount)numberFrames {
    UInt32 aCount = bufferListInOut->mNumberBuffers;
    for (UInt32 i = 0; i < bufferListInOut->mNumberBuffers; i++) {
        AudioBuffer *pBuffer = &bufferListInOut->mBuffers[i];
        UInt32 cSamples = (UInt32) (numberFrames * pBuffer->mNumberChannels);
        float *pData = (float *)pBuffer->mData;
        float channelVolumeList = 0.0f;
        for (UInt32 j = 0; j < cSamples; j++) {
            channelVolumeList += pData[j] * pData[j];
        }
        if (cSamples > 0) {
            channelVolumeList = sqrtf(channelVolumeList / cSamples);
        }
        [self updateChannelVolumeList:&channelVolumeList withChannelVolumeListCount:aCount];
    }
}

- (void)updateChannelVolumeList:(float *)channelVolumeList withChannelVolumeListCount:(UInt32)iCount {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.isPlayed && iCount > 0) {
                float power = channelVolumeList[0];
                BOOL louddly = (power >= (0.003 * self.volume)) ? YES : NO;
                [self.delegate player:self louddly:louddly power:power];
            }
        });
    }
}

#pragma mark - Observers

- (void)addObserversForItem:(AVPlayerItem *)item {
    [self addStatusObserverForItem:item];
    [self addPlaybackLikelyObserverForItem:item];
    [self addBufferFullObserverForItem:item];
    [self addBufferEmptyObserverForItem:item];
}

- (void)addStatusObserverForItem:(AVPlayerItem *)item {
    NSKeyValueObservingOptions options =
    NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial;
    
    [item addObserver:self
           forKeyPath:AZPlayerKeyPathStatus
              options:options
              context:nil];
}

- (void)addPlaybackLikelyObserverForItem:(AVPlayerItem *)item {
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew;
    
    [item addObserver:self
           forKeyPath:AZPlayerKeyPathPlaybackLikely
              options:options
              context:nil];
}

- (void)addBufferFullObserverForItem:(AVPlayerItem *)item {
    NSKeyValueObservingOptions options =
    NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial;
    
    [item addObserver:self
           forKeyPath:AZPlayerKeyPathBufferFull
              options:options
              context:nil];
}

- (void)addBufferEmptyObserverForItem:(AVPlayerItem *)item {
    NSKeyValueObservingOptions options =
    NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial;
    
    [item addObserver:self
           forKeyPath:AZPlayerKeyPathBufferEmpty
              options:options
              context:nil];
}

- (void)addPeriodicTimeObserver {
    CMTime interval = CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC);
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    __weak AZPlayer *weakSelf = self;
    self.timeObserverToken =
    [self.player addPeriodicTimeObserverForInterval:interval
                                              queue:mainQueue
                                         usingBlock:^(CMTime time) {
                                             AZPlayer *strongSelf = weakSelf;
                                             strongSelf->_currentTime = (NSInteger) (time.value/time.timescale);
                                             [strongSelf.delegate player:strongSelf
                                                             currentTime:strongSelf->_currentTime];
                                         }];
    
}

- (void)removeObservers {
    [self.player.currentItem removeObserver:self forKeyPath:AZPlayerKeyPathStatus];
    [self.player.currentItem removeObserver:self forKeyPath:AZPlayerKeyPathPlaybackLikely];
    [self.player.currentItem removeObserver:self forKeyPath:AZPlayerKeyPathBufferFull];
    if (self.timeObserverToken) {
        [self.player removeTimeObserver:self.timeObserverToken];
    }
}

- (void)changePlayerStatus:(NSDictionary<NSString *,id> *)change {
    AVPlayerItemStatus status = AVPlayerItemStatusUnknown;
    NSNumber *statusNumber = change[NSKeyValueChangeNewKey];
    if ([statusNumber isKindOfClass:[NSNumber class]]) {
        status = statusNumber.integerValue;
    }
    switch (status) {
        case AVPlayerItemStatusReadyToPlay:
            [self.delegate readyToPlay:self];
            break;
        case AVPlayerItemStatusFailed:
            _isPlayed = NO;
            [self.delegate failedPlayer:self withError:self.player.currentItem.error];
            break;
        case AVPlayerItemStatusUnknown:
            _isPlayed = NO;
            [self.delegate notReadyToPlay:self];
            break;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:AZPlayerKeyPathStatus]) {
        [self changePlayerStatus:change];
        return;
    }
    if ([keyPath isEqualToString:AZPlayerKeyPathPlaybackLikely]) {
        [self.delegate play:self
            withOutStalling:self.player.currentItem.playbackLikelyToKeepUp];
        return;
    }
    if ([keyPath isEqualToString:AZPlayerKeyPathBufferFull]) {
        [self.delegate bufferFull:self.player.currentItem.playbackBufferFull inPlayer:self];
        return;
    }
    if ([keyPath isEqualToString:AZPlayerKeyPathBufferEmpty]) {
        [self.delegate bufferEmpty:self.player.currentItem.playbackBufferEmpty inPlayer:self];
        return;
    }
}

#pragma mark - Notifications

- (void)addNotificationsForItem:(AVPlayerItem *)item {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemDidPlayToEndTimeNotification:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];
}

- (void)itemDidPlayToEndTimeNotification:(NSNotification *)notification {
    _isPlayed = NO;
    [self.delegate playToEnd:self];
}

- (void)removeNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:self.player.currentItem];
}

@end
