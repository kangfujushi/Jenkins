//
//  STBroswerImageView.m
//  STPhotoBroeser
//
//  Created by zhaoning1 on 2018/3/19.
//  Copyright © 2018年 StriEver. All rights reserved.
//

#import "STBroswerImageView.h"
#import "STImageVIew.h"
#import "STPhotoBroswer.h"

@implementation STBroswerImageView

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.userInteractionEnabled = YES;
    [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clickImage)]];
}

- (void)clickImage {
    STPhotoBroswer * broser = [[STPhotoBroswer alloc]initWithImageArray:@[self.image] currentIndex:0];
    [broser show];
}

@end
