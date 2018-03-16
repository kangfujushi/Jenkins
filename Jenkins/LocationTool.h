//
//  LocationTool.h
//  Jenkins
//
//  Created by zhaoning1 on 2018/3/8.
//  Copyright © 2018年 赵宁. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

typedef void(^LocationBlock)(NSString *string);

@interface LocationTool : NSObject

+ (LocationTool *)sharedLocationTool;
- (void)getCurrentCity:(LocationBlock)locationBlock;

@end
