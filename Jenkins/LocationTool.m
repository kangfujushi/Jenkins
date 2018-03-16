//
//  LocationTool.m
//  Jenkins
//
//  Created by zhaoning1 on 2018/3/8.
//  Copyright © 2018年 赵宁. All rights reserved.
//

#import "LocationTool.h"
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, LocationType)
{
    LTCurrentCity       = 0,
    LTStrLatitude,
    LTStrLongitude,
};

@interface LocationTool ()<CLLocationManagerDelegate>
@property (nonatomic,strong) CLLocationManager *locationManager;     //定位服务
@property (nonatomic, copy) NSString *currentCity;                   //城市
@property (nonatomic, copy) NSString *strLatitude;                   //经度
@property (nonatomic, copy) NSString *strLongitude;                  //维度

@property (nonatomic, strong) LocationBlock locationBlock;
@property (nonatomic, assign) LocationType locationType;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@end

@implementation LocationTool

+ (LocationTool *)sharedLocationTool {
    
    static LocationTool *instance = nil;
    static dispatch_once_t oncet;
    dispatch_once(&oncet,^{
        instance = [[LocationTool alloc] init];
        instance.semaphore = dispatch_semaphore_create(0);
    });
    
    return  instance;
}

- (void)getCurrentCity:(LocationBlock)locationBlock {
    
    _locationBlock = locationBlock;
    _locationType = LTCurrentCity;
    _locationManager = [[CLLocationManager alloc]init];
    _locationManager.delegate = self;
    [_locationManager requestAlwaysAuthorization];
    _currentCity = [[NSString alloc]init];
    [_locationManager requestWhenInUseAuthorization];
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    _locationManager.distanceFilter = 5.0;
    [_locationManager startUpdatingLocation];
}

#pragma mark - 定位失败
-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"请在设置中打开定位" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"打开定位" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSURL *settingURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        [[UIApplication sharedApplication]openURL:settingURL];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [alert addAction:cancel];
    [alert addAction:ok];
    [[UIApplication sharedApplication].keyWindow.window.rootViewController presentViewController:alert animated:YES completion:nil];
}
#pragma mark - 定位成功
-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
    
    [_locationManager stopUpdatingLocation];
    CLLocation *currentLocation = [locations lastObject];
    CLGeocoder *geoCoder = [[CLGeocoder alloc]init];
    //当前的经纬度
    NSLog(@"当前的经纬度 %f,%f",currentLocation.coordinate.latitude,currentLocation.coordinate.longitude);
    //这里的代码是为了判断didUpdateLocations调用了几次 有可能会出现多次调用 为了避免不必要的麻烦 在这里加个if判断 如果大于1.0就return
//    NSTimeInterval locationAge = -[currentLocation.timestamp timeIntervalSinceNow];
    //地理反编码 可以根据坐标(经纬度)确定位置信息(街道 门牌等)
    [geoCoder reverseGeocodeLocation:currentLocation completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (placemarks.count >0) {
            CLPlacemark *placeMark = placemarks[0];
            _currentCity = placeMark.locality;
            if (!_currentCity) {
                _currentCity = @"无法定位当前城市";
            }
            //看需求定义一个全局变量来接收赋值
            NSLog(@"当前国家 - %@",placeMark.country);//当前国家
            NSLog(@"当前城市 - %@",_currentCity);//当前城市
            NSLog(@"当前位置 - %@",placeMark.subLocality);//当前位置
            NSLog(@"当前街道 - %@",placeMark.thoroughfare);//当前街道
            NSLog(@"具体地址 - %@",placeMark.name);//具体地址
            
            NSString *objString = nil;
            switch (_locationType) {
                case LTCurrentCity:
                {
                    objString = _currentCity;
                }
                    break;
                case LTStrLatitude:
                {
                    objString = @(currentLocation.coordinate.latitude).stringValue;
                }
                    break;
                case LTStrLongitude:
                {
                    objString = @(currentLocation.coordinate.longitude).stringValue;
                }
                    break;
                    
                default:
                    break;
            }
            
            _locationBlock(objString);
            
//            NSString *message = [NSString stringWithFormat:@"%@,%@,%@,%@,%@",placeMark.country,_currentCity,placeMark.subLocality,placeMark.thoroughfare,placeMark.name];
//            
//            UIAlertView *alert = [[UIAlertView alloc]initWithTitle:nil message:message delegate:self cancelButtonTitle:nil otherButtonTitles:@"好", nil];
//            [alert show];
        }else if (error == nil && placemarks.count){
            
            NSLog(@"NO location and error return");
        }else if (error){
            
            NSLog(@"loction error:%@",error);
        }
    }];
}

@end
