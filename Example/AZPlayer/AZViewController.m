//
//  AZViewController.m
//  AZPlayer
//
//  Created by alxzorg@gmail.com on 07/29/2019.
//  Copyright (c) 2019 alxzorg@gmail.com. All rights reserved.
//

#import "AZViewController.h"
#import "AZPlayer.h"

@interface AZViewController ()

@property (strong, nonatomic) AZPlayer *player;

@end

@implementation AZViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSURL *remoteUrl = [NSURL URLWithString:@"https://media.louddly.com/podcasts/4d79b3d3-972d-4c6d-9e82-c7269beb20e9/episodes/7953b2ba-7dd4-4bc2-969d-6b68cd3c2868/audio/f5uk2x4d0i4esy88zzbb1v"];
    self.player = [[AZPlayer alloc] initWithURL:remoteUrl];
    [self.player play];
}

@end
