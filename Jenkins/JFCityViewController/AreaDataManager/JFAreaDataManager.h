//
//  JFAreaDataManager.h
//  JFFootball
//
//  Created by 张志峰 on 2016/11/18.
//  Copyright © 2016年 zhifenx. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JFAreaDataManager : NSObject

+ (JFAreaDataManager *)shareInstance;

- (void)areaSqliteDBData;


/**
 从shop_area.sqlite获取所有市

 @param cityData 查询返回值，所有市区数组
 */
- (void)cityData:(void (^)(NSMutableArray *dataArray))cityData;


/**
 获取市对应的city_number

 @param city 查询对象（城市名）
 @param cityNumber 查询返回值（city_number）
 */
- (void)cityNumberWithCity:(NSString *)city cityNumber:(void (^)(NSString *cityNumber))cityNumber IsAbroad:(BOOL)isAbroad;

/**
 获取某个市的所有区县

 @param cityNumber 查询对象
 @param areaData 查询返回值,该市的所有区县数组
 */
- (void)areaData:(NSString *)cityNumber areaData:(void (^)(NSMutableArray *areaData))areaData IsAbroad:(BOOL)isAbroad;


/**
 根据city_number获取当前城市名字

 @param cityNumber 城市ID
 @param currentCityName 当前城市名字
 */
- (void)currentCity:(NSString *)cityNumber currentCityName:(void (^)(NSString *name))currentCityName IsAboad:(BOOL)isAbrod;


/**
 使用搜索框，搜索城市

 @param searchObject 搜索对象
 @param result 搜索回调结果
 */
- (void)searchCityData:(NSString *)searchObject result:(void (^)(NSMutableArray *result))result;


/**
 从shop_area.sqlite获取所有市
 
 @param countryData 查询返回值，所有国家数组
 */
- (void)countryData:(void (^)(NSMutableArray *countryData))countryData;


/**
 从shop_area.sqlite获取所有市
 
 @param searchObject 查询值
 @param cityData  查询返回值，根据国家名获取城市
 */
- (void)searchCityData:(NSString *)searchObject IsSearch:(BOOL)isSearch CityData:(void (^)(NSMutableArray *cityData))cityData;
@end
