//
//  JFAreaDataManager.m
//  JFFootball
//
//  Created by 张志峰 on 2016/11/18.
//  Copyright © 2016年 zhifenx. All rights reserved.
//

#import "JFAreaDataManager.h"

#import "FMDB.h"

@interface JFAreaDataManager ()

@property (nonatomic, strong) FMDatabase *db;

@end

@implementation JFAreaDataManager

static JFAreaDataManager *manager = nil;
+ (JFAreaDataManager *)shareInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
        [manager areaSqliteDBData];
    });
    return manager;
}

- (void)areaSqliteDBData {
    // copy"area.sqlite"到Documents中
    NSFileManager *fileManager =[NSFileManager defaultManager];
    NSError *error;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory =[paths objectAtIndex:0];
    NSString *txtPath =[documentsDirectory stringByAppendingPathComponent:@"shop_area.sqlite"];
    if([fileManager fileExistsAtPath:txtPath] == NO){
        NSString *resourcePath =[[NSBundle mainBundle] pathForResource:@"shop_area" ofType:@"sqlite"];
        [fileManager copyItemAtPath:resourcePath toPath:txtPath error:&error];
    }
    // 新建数据库并打开
    NSString *path  = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject]stringByAppendingPathComponent:@"shop_area.sqlite"];
    FMDatabase *db = [FMDatabase databaseWithPath:path];
    self.db = db;
    [db open];
}

#pragma mark --- 所有市区的名称
- (void)cityData:(void (^)(NSMutableArray *dataArray))cityData {
    NSMutableArray *resultArray = [[NSMutableArray alloc] init];
    FMResultSet *result = [self.db executeQuery:@"SELECT DISTINCT city_name FROM 'main'.'xm_china'"];
    while ([result next]) {
        NSString *cityName = [result stringForColumn:@"city_name"];
        [resultArray addObject:cityName];
    }
    cityData(resultArray);
}

#pragma mark --- 获取当前市的city_code
- (void)cityNumberWithCity:(NSString *)city cityNumber:(void (^)(NSString *cityNumber))cityNumber IsAbroad:(BOOL)isAbroad {
    NSString *sql = isAbroad?[NSString stringWithFormat:@"SELECT DISTINCT city_code FROM xm_abroad WHERE city_name = '%@';",city]:[NSString stringWithFormat:@"SELECT DISTINCT city_code FROM xm_china WHERE city_name = '%@';",city];
    FMResultSet *result = [self.db executeQuery:sql];
    BOOL isBlock = YES;
    while ([result next]) {
        NSString *number = [result stringForColumn:@"city_code"];
        cityNumber(number);
        isBlock = NO;
    }
    if (isBlock) {
        cityNumber(@"");
    }
}

#pragma mark --- 所有区县的名称
- (void)areaData:(NSString *)cityNumber areaData:(void (^)(NSMutableArray *areaData))areaData IsAbroad:(BOOL)isAbroad{
    NSMutableArray *resultArray = [[NSMutableArray alloc] init];
    NSString *sql = isAbroad?[NSString stringWithFormat:@"SELECT DISTINCT area_name FROM 'main'.'xm_abroad' WHERE city_code = '%@';",cityNumber]:[NSString stringWithFormat:@"SELECT DISTINCT area_name FROM xm_china WHERE city_code = '%@';",cityNumber];
    FMResultSet *result = [self.db executeQuery:sql];
    while ([result next]) {
        NSString *areaName = [result stringForColumn:@"area_name"];
        if (areaName) {
            [resultArray addObject:areaName];
        }
    }
    areaData(resultArray);
}

#pragma mark --- 根据city_number获取当前城市
- (void)currentCity:(NSString *)cityNumber currentCityName:(void (^)(NSString *name))currentCityName {
    FMResultSet *result = [self.db executeQuery:[NSString stringWithFormat:@"SELECT DISTINCT city_name FROM xm_china WHERE city_code = '%@';",cityNumber]];
    while ([result next]) {
        NSString *name = [result stringForColumn:@"city_name"];
        currentCityName(name);
    }
}

#pragma mark --- 根据城市名获取镇区
- (void)searchCityData:(NSString *)searchObject result:(void (^)(NSMutableArray *result))result {
    NSMutableArray *resultArray = [[NSMutableArray alloc] init];
    FMResultSet *areaResult = [self.db executeQuery:[NSString stringWithFormat:@"SELECT DISTINCT area_name,city_name,city_code FROM xm_china WHERE area_name LIKE '%@%%';",searchObject]];
    while ([areaResult next]) {
        NSString *area = [areaResult stringForColumn:@"area_name"];
        NSString *city = [areaResult stringForColumn:@"city_name"];
        NSString *cityNumber = [areaResult stringForColumn:@"city_code"];
        NSDictionary *dataDic = @{@"super":city,@"city":area,@"city_number":cityNumber};
        [resultArray addObject:dataDic];
    }
    
    if (resultArray.count == 0) {
        FMResultSet *cityResult = [self.db executeQuery:[NSString stringWithFormat:@"SELECT DISTINCT city_name,city_code,province_name FROM xm_china WHERE city_name LIKE '%@%%';",searchObject]];
            while ([cityResult next]) {
                NSString *city = [cityResult stringForColumn:@"city_name"];
                NSString *cityNumber = [cityResult stringForColumn:@"city_code"];
                NSString *province = [cityResult stringForColumn:@"province_name"];
                NSDictionary *dataDic = @{@"super":province,@"city":city,@"city_number":cityNumber};
                [resultArray addObject:dataDic];
            }
        
        if (resultArray.count == 0) {
            FMResultSet *provinceResult = [self.db executeQuery:[NSString stringWithFormat:@"SELECT DISTINCT province_name,city_name,city_code FROM xm_china WHERE province_name LIKE '%@%%';",searchObject]];
            
            while ([provinceResult next]) {
                NSString *province = [provinceResult stringForColumn:@"province_name"];
                NSString *city = [provinceResult stringForColumn:@"city_name"];
                NSString *cityNumber = [provinceResult stringForColumn:@"city_code"];
                NSDictionary *dataDic = @{@"super":province,@"city":city,@"city_number":cityNumber};
                [resultArray addObject:dataDic];
            }
            
            //统一在数组中传字典是为了JFSearchView解析数据时方便
            if (resultArray.count == 0) {
                [resultArray addObject:@{@"city":@"抱歉",@"super":@"未找到相关位置，可尝试修改后重试!"}];
            }
        }
    }
    //返回结果
    result(resultArray);
}

#pragma mark --- 国外 --- 获取所有国家
- (void)countryData:(void (^)(NSMutableArray *countryData))countryData {
    NSMutableArray *resultArray = [[NSMutableArray alloc] init];
    FMResultSet *result = [self.db
                           executeQuery
                           :@"SELECT DISTINCT city_name FROM 'main'.'xm_abroad'"];
    while ([result next]) {
        NSString *cityName = [result stringForColumn:@"city_name"];
        if (cityName) {
            [resultArray addObject:cityName];
        }
    }
    
    countryData(resultArray);
}

#pragma mark --- 国外 --- 根据国家名获取城市
- (void)searchCityData:(NSString *)searchObject IsSearch:(BOOL)isSearch CityData:(void (^)(NSMutableArray *cityData))cityData {
    NSMutableArray *resultArray = [[NSMutableArray alloc] init];
    if (isSearch) {
        FMResultSet *areaResult = [self.db executeQuery:[NSString stringWithFormat:@"SELECT DISTINCT area_name,city_name,city_code FROM xm_abroad WHERE area_name LIKE '%@%%';",searchObject]];
        while ([areaResult next]) {
            NSString *area = [areaResult stringForColumn:@"area_name"];
            NSString *city = [areaResult stringForColumn:@"city_name"];
            [resultArray addObject:area];
            [resultArray addObject:city];
        }
        
        //统一在数组中传字典是为了JFSearchView解析数据时方便
        if (resultArray.count == 0) {
            [resultArray addObject:@{@"city":@"抱歉",@"super":@"未找到相关位置，可尝试修改后重试!"}];
        }
    } else {
        FMResultSet *areaResult = [self.db executeQuery:[NSString stringWithFormat:@"SELECT DISTINCT area_name,city_name,city_code FROM xm_abroad WHERE area_name LIKE '%@%%';",searchObject]];
        while ([areaResult next]) {
            NSString *area = [areaResult stringForColumn:@"area_name"];
            NSString *city = [areaResult stringForColumn:@"city_name"];
            NSString *cityNumber = [areaResult stringForColumn:@"city_code"];
            NSDictionary *dataDic = @{@"super":city,@"city":area,@"city_number":cityNumber};
            [resultArray addObject:dataDic];
        }
        
        if (resultArray.count == 0) {
            FMResultSet *cityResult = [self.db executeQuery:[NSString stringWithFormat:@"SELECT DISTINCT city_name,city_code,province_name FROM xm_abroad WHERE city_name LIKE '%@%%';",searchObject]];
            while ([cityResult next]) {
                NSString *city = [cityResult stringForColumn:@"city_name"];
                NSString *cityNumber = [cityResult stringForColumn:@"city_code"];
                //            NSString *province = [cityResult stringForColumn:@"province_name"];
                NSDictionary *dataDic = @{@"super":@"",@"city":city,@"city_number":cityNumber};
                [resultArray addObject:dataDic];
            }
            
            //统一在数组中传字典是为了JFSearchView解析数据时方便
            if (resultArray.count == 0) {
                [resultArray addObject:@{@"city":@"抱歉",@"super":@"未找到相关位置，可尝试修改后重试!"}];
            }
        }
    }
    
    //返回结果
    cityData(resultArray);
}


@end
