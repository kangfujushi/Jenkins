//
//  JFCityViewController.m
//  JFFootball
//
//  Created by 张志峰 on 2016/11/21.
//  Copyright © 2016年 zhifenx. All rights reserved.
//

#import "JFCityViewController.h"

#import "JFCityTableViewCell.h"
#import "JFCityHeaderView.h"
#import "JFAreaDataManager.h"
#import "JFLocation.h"
#import "JFSearchView.h"

#define kCurrentCityInfoDefaults [NSUserDefaults standardUserDefaults]

@interface JFCityViewController ()
<UITableViewDelegate,
UITableViewDataSource,
JFLocationDelegate,
JFCityHeaderViewDelegate,
JFSearchViewDelegate>

{
    NSMutableArray   *_indexMutableArray;           //存字母索引下标数组
    NSMutableArray   *_sectionMutableArray;         //存处理过以后的数组
    NSInteger        _HeaderSectionTotal;           //头section的个数
    CGFloat          _cellHeight;                   //添加的(显示区县名称)cell的高度
    BOOL             _isAbroad;                     //判断是否是国外
}

@property (nonatomic, strong) UITableView *rootTableView;
@property (nonatomic, strong) JFCityTableViewCell *cell;
@property (nonatomic, strong) JFCityHeaderView *headerView;
@property (nonatomic, strong) JFAreaDataManager *manager;
@property (nonatomic, strong) JFLocation *locationManager;
@property (nonatomic, strong) JFSearchView *searchView;
/** 最近访问的城市*/
@property (nonatomic, strong) NSMutableArray *historyCityMutableArray;
/** 热门城市*/
@property (nonatomic, strong) NSArray *hotCityArray;
/** 字母索引*/
@property (nonatomic, strong) NSMutableArray *characterMutableArray;
/** 所有“市”级城市名称*/
@property (nonatomic, strong) NSMutableArray *cityMutableArray;
/** 根据cityNumber在数据库中查到的区县*/
@property (nonatomic, strong) NSMutableArray *areaMutableArray;

@end

@implementation JFCityViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _HeaderSectionTotal = 3;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(chooseCityWithName:) name:JFCityTableViewCellDidChangeCityNotification object:nil];
    
    [self.view addSubview:self.rootTableView];
    self.rootTableView.tableHeaderView = self.headerView;
    
    [self backBarButtonItem];
    
    _indexMutableArray = [NSMutableArray array];
    _sectionMutableArray = [NSMutableArray array];
    _manager = [JFAreaDataManager shareInstance];
    _isAbroad = [[kCurrentCityInfoDefaults objectForKey:@"isAbroad"] boolValue];
    self.headerView.delegate = self;
    if (_isAbroad) {
        _headerView.buttonTitle = @"选择州市";
    } else {
        _headerView.buttonTitle = @"选择区县";
    }
    
    [self updateData];
    [self createSegMentController];
}

#pragma mark --- 刷新数据
- (void)updateData {
    [self getData:_isAbroad Result:^(id result) {
        
    }];
}

-(void)getData:(BOOL)isAbroad Result:(void (^) (id result))result {
    NSString *string = nil;
    if (isAbroad) {
        string = @"abroad";
    } else {
        string = @"";
    }
    if ([kCurrentCityInfoDefaults objectForKey:[@"cityData" stringByAppendingString:string]]) {
        self.characterMutableArray = [NSKeyedUnarchiver unarchiveObjectWithData:[kCurrentCityInfoDefaults objectForKey:[@"cityData" stringByAppendingString:string]]];
        _sectionMutableArray = [NSKeyedUnarchiver unarchiveObjectWithData:[kCurrentCityInfoDefaults objectForKey:[@"sectionData" stringByAppendingString:string]]];
        [_rootTableView reloadData];
    }else {
        //在子线程中异步执行汉字转拼音再转汉字耗时操作
        _manager = [JFAreaDataManager shareInstance];
        __weak typeof(self) weakSelf = self;
        if (isAbroad) {
            [_manager countryData:^(NSMutableArray *countryData) {
                //立刻生成一个strong引用，以保证实例在执行期间持续存活
                __strong typeof(self) strongSelf = weakSelf;
                if (strongSelf) {
                    strongSelf.cityMutableArray = countryData;
                    
                    dispatch_queue_t serialQueue = dispatch_queue_create("com.city.www", DISPATCH_QUEUE_SERIAL);
                    dispatch_async(serialQueue, ^{
                        [self processData:countryData IsAbroad:isAbroad Succese:^(id success) {
                            //回到主线程刷新UI
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [_rootTableView reloadData];
                                self.locationManager = [[JFLocation alloc] init];
                                _locationManager.delegate = self;
                            });
                        }];
                    });
                }
            }];
        } else {
            [_manager cityData:^(NSMutableArray *dataArray) {
                //立刻生成一个strong引用，以保证实例在执行期间持续存活
                __strong typeof(self) strongSelf = weakSelf;
                if (strongSelf) {
                    strongSelf.cityMutableArray = dataArray;
                    
                    dispatch_queue_t serialQueue = dispatch_queue_create("com.city.www", DISPATCH_QUEUE_SERIAL);
                    dispatch_async(serialQueue, ^{
                        [self processData:dataArray IsAbroad:isAbroad Succese:^(id success) {
                            //回到主线程刷新UI
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [_rootTableView reloadData];
                                self.locationManager = [[JFLocation alloc] init];
                                _locationManager.delegate = self;
                            });
                        }];
                    });
                }
            }];
        }
    }
    
    self.historyCityMutableArray = [NSKeyedUnarchiver unarchiveObjectWithData:[kCurrentCityInfoDefaults objectForKey:[@"historyCity" stringByAppendingString:string]]];
}

-(void)createSegMentController{
    NSArray *segmentedArray = [NSArray arrayWithObjects:@"国内",@"国外",nil];
    
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc]initWithItems:segmentedArray];
    
    segmentedControl.frame = CGRectMake(0, 0, 180, 30);
    
    segmentedControl.selectedSegmentIndex = _isAbroad;
    segmentedControl.tintColor = [UIColor grayColor];
    
    [segmentedControl addTarget:self action:@selector(indexDidChangeForSegmentedControl:) forControlEvents:UIControlEventValueChanged];
    
    [self.navigationItem setTitleView:segmentedControl];
}

-(void)indexDidChangeForSegmentedControl:(UISegmentedControl *)sender
{
    //我定义了一个 NSInteger tag，是为了记录我当前选择的是分段控件的左边还是右边。
    NSInteger selecIndex = sender.selectedSegmentIndex;
    _isAbroad = selecIndex;
    [kCurrentCityInfoDefaults setObject:@(selecIndex) forKey:@"isAbroad"];
    
    if (_isAbroad) {
        _headerView.buttonTitle = @"选择州市";
    } else {
        _headerView.buttonTitle = @"选择区县";
    }
    [self updateData];
}

- (void)backBarButtonItem {
    UIButton *leftButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 50, 30)];
    [leftButton addTarget:self action:@selector(backrootTableViewController) forControlEvents:UIControlEventTouchUpInside];
    [leftButton setTitle:@"Back" forState:UIControlStateNormal];
    [leftButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:leftButton];
}

/// 选择城市时调用通知函数（前提是点击cell的section < 3）
- (void)chooseCityWithName:(NSNotification *)info {
    NSDictionary *cityDic = info.userInfo;
    NSString *cityName = [[NSString alloc] init];
    if ([[cityDic valueForKey:@"cityName"] isEqualToString:@"全城"]) {
        __weak typeof(self) weakSelf = self;
        [_manager currentCity:[kCurrentCityInfoDefaults objectForKey:@"cityNumber"] currentCityName:^(NSString *name) {
            [kCurrentCityInfoDefaults setObject:name forKey:@"currentCity"];
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                strongSelf.headerView.cityName = name;
                if (strongSelf.delegate && [strongSelf.delegate respondsToSelector:@selector(cityName:)]) {
                    [strongSelf.delegate cityName:name];
                }
            }
        } IsAboad:_isAbroad];
    }else {
        cityName = [cityDic valueForKey:@"cityName"];
        _headerView.cityName = cityName;
        [kCurrentCityInfoDefaults setObject:[cityDic valueForKey:@"cityName"] forKey:@"currentCity"];
        if (self.delegate && [self.delegate respondsToSelector:@selector(cityName:)]) {
            [self.delegate cityName:cityName];
        }
        [_manager cityNumberWithCity:[cityDic valueForKey:@"cityName"] cityNumber:^(NSString *cityNumber) {
            [kCurrentCityInfoDefaults setObject:cityNumber forKey:@"cityNumber"];
        } IsAbroad:_isAbroad];
        
        [self historyCity:cityName];
    }
    
    //销毁通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSMutableArray *)areaMutableArray {
    if (!_areaMutableArray) {
        _areaMutableArray = [NSMutableArray arrayWithObject:@"全城"];
    }
    return _areaMutableArray;
}

- (JFCityHeaderView *)headerView {
    if (!_headerView) {
        _headerView = [[JFCityHeaderView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 80)];
        _headerView.delegate = self;
        _headerView.backgroundColor = [UIColor whiteColor];
        _headerView.buttonTitle = @"选择区县";
        _headerView.cityName = [kCurrentCityInfoDefaults objectForKey:@"currentCity"] ? [kCurrentCityInfoDefaults objectForKey:@"currentCity"] : [kCurrentCityInfoDefaults objectForKey:@"locationCity"];
    }
    
    return _headerView;
}

- (JFSearchView *)searchView {
    if (!_searchView) {
        CGRect frame = [UIScreen mainScreen].bounds;
        _searchView = [[JFSearchView alloc] initWithFrame:CGRectMake(0, 104, frame.size.width, frame.size.height  - 104)];
        _searchView.backgroundColor = [UIColor colorWithRed:155 / 255.0 green:155 / 255.0 blue:155 / 255.0 alpha:0.5];
        _searchView.delegate = self;
    }
    return _searchView;
}

/// 移除搜索界面
- (void)deleteSearchView {
    [_searchView removeFromSuperview];
    _searchView = nil;
}

- (NSMutableArray *)historyCityMutableArray {
    if (!_historyCityMutableArray) {
        _historyCityMutableArray = [[NSMutableArray alloc] init];
    }
    return _historyCityMutableArray;
}

- (NSArray *)hotCityArray {
    if (_isAbroad) {
        _hotCityArray = @[@"威尼斯", @"阿姆斯特丹", @"马尔代夫", @"迪拜", @"新加坡", @"巴厘岛", @"普吉岛", @"巴塞罗那", @"普罗旺斯", @"加勒比海"];
    } else {
        _hotCityArray = @[@"北京市", @"上海市", @"广州市", @"深圳市", @"武汉市", @"天津市", @"西安市", @"南京市", @"杭州市", @"成都市", @"重庆市"];
    }
    return _hotCityArray;
}

- (NSMutableArray *)characterMutableArray {
    if (!_characterMutableArray) {
        _characterMutableArray = [NSMutableArray arrayWithObjects:@"!", @"#", @"$", nil];
    }
    return _characterMutableArray;
}

/// 汉字转拼音再转成汉字
-(void)processData:(NSArray *)dataArray IsAbroad:(BOOL)isAbroad Succese:(void (^) (id success))success {
    NSMutableArray *indexMutableArray =   [NSMutableArray array];
    NSMutableArray *sectionMutableArray = [NSMutableArray array];
    
    for (int i = 0; i < dataArray.count; i ++) {
        NSString *str = dataArray[i]; //一开始的内容
        if (str.length) {  //下面那2个转换的方法一个都不能少
            NSMutableString *ms = [[NSMutableString alloc] initWithString:str];
            //汉字转拼音
            if (CFStringTransform((__bridge CFMutableStringRef)ms, 0, kCFStringTransformMandarinLatin, NO)) {
            }
            //拼音转英文
            if (CFStringTransform((__bridge CFMutableStringRef)ms, 0, kCFStringTransformStripDiacritics, NO)) {
                //字符串截取第一位，并转换成大写字母
                NSString *firstStr = [[ms substringToIndex:1] uppercaseString];
                //如果不是字母开头的，转为＃
                BOOL isLetter = [self matchLetter:firstStr];
                if (!isLetter)
                    firstStr = @"#";
                
                //如果还没有索引
                if (indexMutableArray.count <= 0) {
                    //保存当前这个做索引
                    [indexMutableArray addObject:firstStr];
                    //用这个字母做字典的key，将当前的标题保存到key对应的数组里面去
                    NSMutableArray *array = [NSMutableArray arrayWithObject:str];
                    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithObjectsAndKeys:array,firstStr, nil];
                    [sectionMutableArray addObject:dic];
                }else{
                    //如果索引里面包含了当前这个字母，直接保存数据
                    if ([indexMutableArray containsObject:firstStr]) {
                        //取索引对应的数组，保存当前标题到数组里面
                        NSMutableArray *array = sectionMutableArray[0][firstStr];
                        [array addObject:str];
                        //重新保存数据
                        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithObjectsAndKeys:array,firstStr, nil];
                        [sectionMutableArray addObject:dic];
                    }else{
                        //如果没有包含，说明是新的索引
                        [indexMutableArray addObject:firstStr];
                        //用这个字母做字典的key，将当前的标题保存到key对应的数组里面去
                        NSMutableArray *array = [NSMutableArray arrayWithObject:str];
                        NSMutableDictionary *dic = sectionMutableArray[0];
                        [dic setObject:array forKey:firstStr];
                        [sectionMutableArray addObject:dic];
                    }
                }
            }
        }
    }
    
    //将字母排序
    NSArray *compareArray = [[sectionMutableArray[0] allKeys] sortedArrayUsingSelector:@selector(compare:)];
    _indexMutableArray =   [NSMutableArray arrayWithArray:compareArray];
    _sectionMutableArray = [NSMutableArray arrayWithArray:sectionMutableArray];
    
    //判断第一个是不是字母，如果不是放到最后一个
    BOOL isLetter = [self matchLetter:_indexMutableArray[0]];
    if (!isLetter) {
        //获取数组的第一个元素
        NSString *firstStr = [_indexMutableArray firstObject];
        //移除第一项元素
        [_indexMutableArray removeObjectAtIndex:0];
        //插入到最后一个位置
        [_indexMutableArray insertObject:firstStr atIndex:_indexMutableArray.count];
    }
    
    [self.characterMutableArray removeAllObjects];
    self.characterMutableArray = nil;
    [self.characterMutableArray addObjectsFromArray:_indexMutableArray];
    NSData *cityData = [NSKeyedArchiver archivedDataWithRootObject:self.characterMutableArray];
    NSData *sectionData = [NSKeyedArchiver archivedDataWithRootObject:_sectionMutableArray];
    
    //拼音转换太耗时，这里把第一次转换结果存到单例中
    NSString *string = nil;
    if (isAbroad) {
        string = @"abroad";
    } else {
        string = @"";
    }
    [kCurrentCityInfoDefaults setValue:cityData forKey:[@"cityData" stringByAppendingString:string]];
    [kCurrentCityInfoDefaults setObject:sectionData forKey:[@"sectionData" stringByAppendingString:string]];
    
    //获取数据
    _cityMutableArray = [NSMutableArray arrayWithArray:dataArray];
    
    success(@"成功");
}

#pragma mark - 匹配是不是字母开头
- (BOOL)matchLetter:(NSString *)str {
    //判断是否以字母开头
    NSString *ZIMU = @"^[A-Za-z]+$";
    NSPredicate *regextestA = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", ZIMU];
    
    if ([regextestA evaluateWithObject:str] == YES)
        return YES;
    else
        return NO;
}

- (void)backrootTableViewController {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UITableView *)rootTableView {
    if (!_rootTableView) {
        _rootTableView = [[UITableView alloc] initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStylePlain];
        _rootTableView.delegate = self;
        _rootTableView.dataSource = self;
        _rootTableView.sectionIndexColor = [UIColor colorWithRed:0/255.0f green:132/255.0f blue:255/255.0f alpha:1];
        [_rootTableView registerClass:[JFCityTableViewCell class] forCellReuseIdentifier:@"cityCell"];
        [_rootTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cityNameCell"];
    }
    return _rootTableView;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _characterMutableArray.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section < _HeaderSectionTotal ? 1 : [((NSArray *)_sectionMutableArray[0][_characterMutableArray[section]]) count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section < _HeaderSectionTotal) {
        self.cell = [tableView dequeueReusableCellWithIdentifier:@"cityCell" forIndexPath:indexPath];
        if (_HeaderSectionTotal == 4 && indexPath.section == 0) {
            _cell.cityNameArray = _areaMutableArray;
        }
        if (indexPath.section == _HeaderSectionTotal - 3) {
            NSString *locationCity = [kCurrentCityInfoDefaults objectForKey:@"locationCity"];
            _cell.cityNameArray = locationCity ? @[locationCity] : @[@"正在定位..."];
        }
        if (indexPath.section == _HeaderSectionTotal - 2) {
            _cell.cityNameArray = self.historyCityMutableArray;
        }
        if (indexPath.section == _HeaderSectionTotal - 1) {
            _cell.cityNameArray = self.hotCityArray;
        }
    return _cell;
    }else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cityNameCell" forIndexPath:indexPath];
        NSArray *currentArray = _sectionMutableArray[0][_characterMutableArray[indexPath.section]];
        cell.textLabel.text = currentArray[indexPath.row];
        cell.textLabel.textColor = [UIColor grayColor];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        return cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_HeaderSectionTotal == 4 && indexPath.section == 0) {
        return _cellHeight;
    }else {
        return indexPath.section == (_HeaderSectionTotal - 1) ? 200 : 44;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (_HeaderSectionTotal == 4 && section == 0) {
        return 0;
    }else{
        return 40;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_HeaderSectionTotal == 3) {
        switch (section) {
            case 0:
                return @"定位城市";
                break;
            case 1:
                return @"最近访问的城市";
                break;
            case 2:
                return @"热门城市";
                break;
            default:
                return _characterMutableArray[section];
                break;
        }
    }else {
        switch (section) {
            case 1:
                return @"定位城市";
                break;
            case 2:
                return @"最近访问的城市";
                break;
            case 3:
                return @"热门城市";
                break;
            default:
                return _characterMutableArray[section];
                break;
        }
    }
}

//设置右侧索引的标题，这里返回的是一个数组哦！
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return _characterMutableArray;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    _headerView.cityName = cell.textLabel.text;
    [kCurrentCityInfoDefaults setObject:cell.textLabel.text forKey:@"currentCity"];
    [_manager cityNumberWithCity:cell.textLabel.text cityNumber:^(NSString *cityNumber) {
        [kCurrentCityInfoDefaults setObject:cityNumber forKey:@"cityNumber"];
    } IsAbroad:_isAbroad];
    if (self.delegate && [self.delegate respondsToSelector:@selector(cityName:)]) {
        [self.delegate cityName:cell.textLabel.text];
    }
    [self historyCity:cell.textLabel.text];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark --- JFCityHeaderViewDelegate

- (void)cityNameWithSelected:(BOOL)selected {
    //获取当前城市的所有辖区
    if (selected) {
//        NSString *string = nil;
//        if (_isAbroad) {
//            string = @"abroad";
//        } else {
//            string = @"";
//        }
        [_manager areaData:[kCurrentCityInfoDefaults objectForKey:@"cityNumber"] areaData:^(NSMutableArray *areaData) {
            [self.areaMutableArray addObjectsFromArray:areaData];
            if (0 == (self.areaMutableArray.count % 3)) {
                _cellHeight = self.areaMutableArray.count / 3 * 50;
            }else {
                _cellHeight = (self.areaMutableArray.count / 3 + 1) * 50;
            }
            if (_cellHeight > 300) {
                _cellHeight = 300;
            }
        } IsAbroad:_isAbroad];
        
        //添加一行cell
        [_rootTableView endUpdates];
        [_characterMutableArray insertObject:@"*" atIndex:0];
        _HeaderSectionTotal = 4;
        NSIndexSet *indexSet = [[NSIndexSet alloc] initWithIndex:0];
        [self.rootTableView insertSections:indexSet withRowAnimation:UITableViewRowAnimationNone];
        [_rootTableView endUpdates];
    }else {
        //清空区县名称数组
        self.areaMutableArray = nil;
        //删除一行cell
        [_rootTableView endUpdates];
        [_characterMutableArray removeObjectAtIndex:0];
        _HeaderSectionTotal = 3;
        NSIndexSet *indexSet = [[NSIndexSet alloc] initWithIndex:0];
        [self.rootTableView deleteSections:indexSet withRowAnimation:UITableViewRowAnimationNone];
        [_rootTableView endUpdates];
    }
}

- (void)beginSearch {
    [self.view addSubview:self.searchView];
}

- (void)endSearch {
    [self deleteSearchView];
}



- (void)searchResult:(NSString *)result {
    if (_isAbroad) {
        [_manager searchCityData:result IsSearch:YES CityData:^(NSMutableArray *cityData) {
            if ([cityData count] > 0) {
                _searchView.backgroundColor = [UIColor whiteColor];
                _searchView.resultMutableArray = cityData;
            }
        }];
    } else {
        [_manager searchCityData:result result:^(NSMutableArray *result) {
            if ([result count] > 0) {
                _searchView.backgroundColor = [UIColor whiteColor];
                _searchView.resultMutableArray = result;
            }
        }];
    }
}

#pragma mark - JFSearchViewDelegate

- (void)searchResults:(NSDictionary *)dic {
    [kCurrentCityInfoDefaults setObject:[dic valueForKey:@"city"] forKey:@"currentCity"];
    [kCurrentCityInfoDefaults setObject:[dic valueForKey:@"city_number"] forKey:@"cityNumber"];
    NSString *nameStr = [dic valueForKey:@"city"];
    if (self.delegate && [self.delegate respondsToSelector:@selector(cityName:)]) {
        [self.delegate cityName:nameStr];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
    [self historyCity:[dic valueForKey:@"city"]];
}

- (void)touchViewToExit {
    [_headerView cancelSearch];
}

#pragma mark - JFLocationDelegate

- (void)locating {
    NSLog(@"定位中。。。");
}

//定位成功
- (void)currentLocation:(NSDictionary *)locationDictionary {
    NSString *city = [locationDictionary valueForKey:@"City"];
    [kCurrentCityInfoDefaults setObject:city forKey:@"locationCity"];
    [_manager cityNumberWithCity:city cityNumber:^(NSString *cityNumber) {
        [kCurrentCityInfoDefaults setObject:cityNumber forKey:@"cityNumber"];
    } IsAbroad:_isAbroad];
    _headerView.cityName = city;
    [self historyCity:city];
    [_rootTableView reloadData];
}

/// 添加历史访问城市
- (void)historyCity:(NSString *)city {
    //避免重复添加，先删除再添加
    [_historyCityMutableArray removeObject:city];
    [_historyCityMutableArray insertObject:city atIndex:0];
    if (_historyCityMutableArray.count > 3) {
        [_historyCityMutableArray removeLastObject];
    }
    NSData *historyCityData = [NSKeyedArchiver archivedDataWithRootObject:self.historyCityMutableArray];
    NSString *string = nil;
    if (_isAbroad) {
        string = @"abroad";
    } else {
        string = @"";
    }
    [kCurrentCityInfoDefaults setObject:historyCityData forKey:[@"historyCity" stringByAppendingString:string]];
}

/// 拒绝定位
- (void)refuseToUsePositioningSystem:(NSString *)message {
    NSLog(@"%@",message);
}

/// 定位失败
- (void)locateFailure:(NSString *)message {
    NSLog(@"%@",message);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    NSLog(@"JFCityViewController dealloc");
}


@end
