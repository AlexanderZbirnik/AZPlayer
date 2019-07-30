//
//  AZViewController.m
//  AZPlayer
//
//  Created by alxzorg@gmail.com on 07/29/2019.
//  Copyright (c) 2019 alxzorg@gmail.com. All rights reserved.
//

#import "AZViewController.h"
#import "AZPlayer.h"

@interface AZViewController () <AZPlayerDelegate>

@property (strong, nonatomic) AZPlayer *player;

@end

@implementation AZViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSURL *remoteUrl = [NSURL URLWithString:@"https://media.louddly.com/podcasts/4d79b3d3-972d-4c6d-9e82-c7269beb20e9/episodes/7953b2ba-7dd4-4bc2-969d-6b68cd3c2868/audio/f5uk2x4d0i4esy88zzbb1v"];
    self.player = [[AZPlayer alloc] initWithURL:remoteUrl];
    self.player.delegate = self;
    self.player.rate = 1.0;
}

#pragma mark - AZPlayerDelegate

- (void)readyToPlay:(AZPlayer *)player {;
     NSLog(@"self.player.duration.value: %lld", self.player.duration.value);
}

- (void)failedPlayer:(AZPlayer *)player withError:(NSError *)error {
    
}

- (void)notReadyToPlay:(AZPlayer *)player {
    
}

- (void)play:(AZPlayer *)player withOutStalling:(BOOL)stalling {
    
}

- (void)bufferFull:(BOOL)full inPlayer:(AZPlayer *)player {
    
}

- (void)bufferEmpty:(BOOL)empty inPlayer:(AZPlayer *)player {
    
}

- (void)player:(AZPlayer *)player louddly:(BOOL)louddly power:(CGFloat)power {
    
}

- (void)player:(AZPlayer *)player currentTime:(NSInteger)time {
    
}

- (void)playToEnd:(AZPlayer *)player {
    
}

@end
