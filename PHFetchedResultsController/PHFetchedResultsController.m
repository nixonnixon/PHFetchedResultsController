//
//  PHFetchedResultsController.m
//  PHFetchedResultsController
//
//  Created by 1amageek on 2015/11/30.
//  Copyright © 2015年 Stamp inc. All rights reserved.
//

#import "PHFetchedResultsController.h"

@protocol PHFetchedResultsSectionInfoDelegate <NSObject>

- (PHFetchedResultsSectionKey)sectionInfoSectionKey;
- (NSDateFormatter *)dateFormatter;
- (NSArray <NSString *>*)ignoreLocalIDs;

@end

@interface PHFetchedResultsSectionInfo : NSObject <PHFetchedResultsSectionInfo>

@property (nonatomic) NSString *name;
@property (nonatomic, readonly) NSInteger year;
@property (nonatomic, readonly) NSInteger month;
@property (nonatomic, readonly) NSInteger week;
@property (nonatomic, readonly) NSInteger day;
@property (nonatomic, readonly) NSInteger hour;
@property (nonatomic, readonly) PHFetchOptions *options;
@property (nonatomic, readonly) PHAssetCollection *assetCollection;
@property (nonatomic, readonly) NSDateComponents *dateComponents;
@property (nonatomic, readwrite) NSUInteger numberOfObjects;
@property (nonatomic, weak) id <PHFetchedResultsSectionInfoDelegate> delegate;

- (instancetype)initWithAssetCollection:(PHAssetCollection *)assetCollection
                                   date:(NSDate *)date
                                options:(PHFetchOptions *)options;

@end

@implementation PHFetchedResultsSectionInfo
{
    NSCache *_cache;
    NSUInteger _numberOfObjects;
}

- (instancetype)initWithAssetCollection:(PHAssetCollection *)assetCollection
                                   date:(NSDate *)date
                                options:(PHFetchOptions *)options
{
    self = [super init];
    if (self) {
        _cache = [NSCache new];
        NSCalendar *calendar = [NSCalendar currentCalendar];
        _dateComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitWeekOfMonth | NSCalendarUnitDay | NSCalendarUnitHour fromDate:date];
        _assetCollection = assetCollection;
        _options = options;
        _numberOfObjects = 1;
    }
    return self;
}

- (NSInteger)year
{
    return [self.dateComponents year];
}

- (NSInteger)month
{
    return [self.dateComponents month];
}

- (NSInteger)week
{
    return [self.dateComponents weekOfMonth];
}

- (NSInteger)day
{
    return [self.dateComponents day];
}

- (NSInteger)hour
{
    return [self.dateComponents hour];
}

- (void)setNumberOfObjects:(NSUInteger)numberOfObjects
{
    _numberOfObjects = numberOfObjects;
    [self removeCache];
}

#pragma mark - PHFetchedResultsSectionInfo

- (NSString *)name
{
    if (_name) {
        return _name;
    }
    NSDateFormatter *dateFormatter = [self.delegate dateFormatter];
    NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:self.dateComponents];
    _name = [dateFormatter stringFromDate:date];
    return _name;
}

- (NSString *)indexTitle
{
    return nil;
}

- (NSUInteger)numberOfObjects
{
    return _numberOfObjects;
}

- (PHFetchResult <PHAsset *>*)objects
{
    NSString *name = [self name];
    PHFetchResult *cacheResult = [_cache objectForKey:name];
    if (cacheResult) {
        return cacheResult;
    }
    
    PHFetchOptions *options = [PHFetchOptions new];
    options.sortDescriptors = self.options.sortDescriptors;
    
    PHFetchedResultsSectionKey sectionKey = [self.delegate sectionInfoSectionKey];
    
    NSDateComponents *dateComponents = [NSDateComponents new];
    NSDateComponents *addDateComponents = [NSDateComponents new];
    NSDate *startDate;
    NSDate *endDate;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    switch (sectionKey) {
        case PHFetchedResultsSectionKeyHour: {
            [dateComponents setYear:self.year];
            [dateComponents setMonth:self.month];
            [dateComponents setWeekOfMonth:self.week];
            [dateComponents setDay:self.day];
            [dateComponents setHour:self.hour];
            startDate = [[NSCalendar currentCalendar] dateFromComponents:dateComponents];
            [addDateComponents setHour:1];
            endDate = [calendar dateByAddingComponents:addDateComponents toDate:startDate options:0];
        }
            break;
        case PHFetchedResultsSectionKeyDay: {
            [dateComponents setYear:self.year];
            [dateComponents setMonth:self.month];
            [dateComponents setWeekOfMonth:self.week];
            [dateComponents setDay:self.day];
            startDate = [[NSCalendar currentCalendar] dateFromComponents:dateComponents];
            [addDateComponents setDay:1];
            endDate = [calendar dateByAddingComponents:addDateComponents toDate:startDate options:0];
        }
            break;
        case PHFetchedResultsSectionKeyWeek: {
            [dateComponents setYear:self.year];
            [dateComponents setMonth:self.month];
            [dateComponents setWeekOfMonth:self.week];
            [dateComponents setWeekday:1];
            startDate = [[NSCalendar currentCalendar] dateFromComponents:dateComponents];
            [addDateComponents setWeekOfMonth:1];
            endDate = [calendar dateByAddingComponents:addDateComponents toDate:startDate options:0];
        }
            break;
        case PHFetchedResultsSectionKeyMonth: {
            [dateComponents setYear:self.year];
            [dateComponents setMonth:self.month];
            startDate = [[NSCalendar currentCalendar] dateFromComponents:dateComponents];
            [addDateComponents setMonth:1];
            endDate = [calendar dateByAddingComponents:addDateComponents toDate:startDate options:0];
        }
            break;
        case PHFetchedResultsSectionKeyYear:
        default:{
            [dateComponents setYear:self.year];
            startDate = [calendar dateFromComponents:dateComponents];
            [addDateComponents setYear:1];
            endDate = [calendar dateByAddingComponents:addDateComponents toDate:startDate options:0];
        }
            break;
    }
    
    NSPredicate *predicate = self.options.predicate;
    NSPredicate *datePredicate = [NSPredicate predicateWithFormat:@"(creationDate >= %@) AND (creationDate < %@)", startDate, endDate];
    NSPredicate *newPredicate;
    if (predicate) {
        newPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, datePredicate]];
    } else {
        newPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[datePredicate]];
    }
    options.predicate = newPredicate;
    PHFetchResult <PHAsset *>*result = [PHAsset fetchAssetsInAssetCollection:self.assetCollection options:options];
    [_cache setObject:result forKey:name];
    
    return result;
}

- (PHAsset *)assetAtIndex:(NSInteger)index
{
    PHAsset *asset = self.objects[index];
    return asset;
}

- (void)removeCache
{
    NSString *name = [self name];
    [_cache removeObjectForKey:name];
}

@end

@implementation PHFetchedResultsSectionChangeDetails
{
    NSMutableIndexSet *__removedIndexes;
    NSMutableIndexSet *__insertedIndexes;
    NSMutableIndexSet *__updatedIndexes;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        __removedIndexes = [NSMutableIndexSet indexSet];
        __insertedIndexes = [NSMutableIndexSet indexSet];
        __updatedIndexes = [NSMutableIndexSet indexSet];
    }
    return self;
}

- (void)addRemovedIndex:(NSUInteger)index
{
    if ([__removedIndexes containsIndex:index]) {
        return;
    }
    [__removedIndexes addIndex:index];
}

- (void)addInsertedIndex:(NSUInteger)index
{
    if ([__insertedIndexes containsIndex:index]) {
        return;
    }
    [__insertedIndexes addIndex:index];
}

- (void)addUpdatedIndex:(NSUInteger)index
{
    if ([__updatedIndexes containsIndex:index]) {
        return;
    }
    [__updatedIndexes addIndex:index];
}

- (void)removeRemovedIndex:(NSUInteger)index
{
    if ([__removedIndexes containsIndex:index]) {
        [__removedIndexes removeIndex:index];
    }
}

- (void)removeInsertedIndex:(NSUInteger)index
{
    if ([__insertedIndexes containsIndex:index]) {
        [__insertedIndexes removeIndex:index];
    }
}

- (void)removeUpdatedIndex:(NSUInteger)index
{
    if ([__updatedIndexes containsIndex:index]) {
        [__updatedIndexes removeIndex:index];
    }
}

- (NSIndexSet *)removedIndexes
{
    return (NSIndexSet *)__removedIndexes;
}

- (NSIndexSet *)insertedIndexes
{
    return (NSIndexSet *)__insertedIndexes;
}

- (NSIndexSet *)updatedIndexes
{
    return (NSIndexSet *)__updatedIndexes;
}

@end

@interface _PHFetchTask : NSObject

@property (readonly) NSUInteger taskIdentifier;
@property (nonatomic, readonly) BOOL isCanceled;

- (void)cancel;

@end

@implementation _PHFetchTask

- (instancetype)init
{
    self = [super init];
    if (self) {
        _isCanceled = NO;
    }
    return self;
}

- (void)cancel
{
    _isCanceled = YES;
}

@end

@interface PHFetchedResultsController () <PHFetchedResultsSectionInfoDelegate, PHPhotoLibraryChangeObserver>

@property (nonatomic)   PHFetchOptions *options;
@property (nonatomic)   PHFetchResult <PHAsset *>*fetchResult;
@property (nonatomic)   NSArray <PHFetchedResultsSectionInfo *>*mySections;

@end

@implementation PHFetchedResultsController
{
    NSDateFormatter *_dateFormatter;
    dispatch_queue_t _queue;
    _PHFetchTask *_runningTask;
}

- (instancetype)initWithAssetCollection:(PHAssetCollection *)assetCollection sectionKey:(PHFetchedResultsSectionKey)sectionKey mediaType:(PHFetchedResultsMediaType)mediaType ignoreLocalIDs:(NSArray <NSString *>*)ignoreLocalIDs
{
    self = [super init];
    if (self) {
        
        _queue = dispatch_queue_create("phfetchedresultscontroller.queue", DISPATCH_QUEUE_SERIAL);
        
        _dateFormatter = [NSDateFormatter new];
        _assetCollection = assetCollection;
        _sectionKey = sectionKey;
        _mediaType = mediaType;
        
        _mySections = [NSMutableArray array];
        _options = [PHFetchOptions new];
        if (ignoreLocalIDs) {
            _options.predicate = [NSPredicate predicateWithFormat:@"NOT (localIdentifier IN %@)", ignoreLocalIDs];
        }
        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    }
    return self;
}

- (void)dealloc {
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

- (void)setIgnoreLocalIDs:(NSArray<NSString *> *)ignoreLocalIDs
{
    _ignoreLocalIDs = ignoreLocalIDs;
    if (_ignoreLocalIDs) {
        _options.predicate = [NSPredicate predicateWithFormat:@"NOT (localIdentifier IN %@)", ignoreLocalIDs];
    }
    [self performFetch:nil];
}

- (BOOL)performFetch:(NSError * _Nullable __autoreleasing *)error
{
    if ((_mediaType & PHFetchedResultsMediaTypeImage) == PHFetchedResultsMediaTypeImage) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
        _options.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[_options.predicate, predicate]];
    }
    if ((_mediaType & PHFetchedResultsMediaTypeVideo) == PHFetchedResultsMediaTypeVideo) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
        _options.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[_options.predicate, predicate]];
    }
    if ((_mediaType & PHFetchedResultsMediaTypeAudio) == PHFetchedResultsMediaTypeAudio) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeAudio];
        _options.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[_options.predicate, predicate]];
    }
    _options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    self.fetchResult = [PHAsset fetchAssetsInAssetCollection:_assetCollection options:_options];
    return YES;
}

- (PHFetchOptions *)alterOptions:(PHFetchOptions *)options
{
    PHFetchOptions *fetchOptions = [PHFetchOptions new];
    if ((_mediaType & PHFetchedResultsMediaTypeImage) == PHFetchedResultsMediaTypeImage) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
        fetchOptions.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[options.predicate, predicate]];
    }
    if ((_mediaType & PHFetchedResultsMediaTypeVideo) == PHFetchedResultsMediaTypeVideo) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
        fetchOptions.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[options.predicate, predicate]];
    }
    if ((_mediaType & PHFetchedResultsMediaTypeAudio) == PHFetchedResultsMediaTypeAudio) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeAudio];
        fetchOptions.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[options.predicate, predicate]];
    }
    fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    return fetchOptions;
}

- (void)setFetchResult:(PHFetchResult<PHAsset *> *)fetchResult
{
    __block PHFetchResult<PHAsset *> *previousFetchResult = _fetchResult;
    _fetchResult = fetchResult;
    
    [self.mySections enumerateObjectsUsingBlock:^(PHFetchedResultsSectionInfo * _Nonnull sectionInfo, NSUInteger idx, BOOL * _Nonnull stop) {
        [sectionInfo removeCache];
    }];
    
    // 処理中のタスクがあればキャンセル
    if (_runningTask) {
        NSLog(@"cancel");
        [_runningTask cancel];
    }
    
    __weak typeof(self) __self = self;

    _runningTask = [self findSectionInfoInAssets:_fetchResult exists:^(PHFetchedResultsSectionInfo *sectionInfo) {
        sectionInfo.numberOfObjects ++;
    } notExists:^PHFetchedResultsSectionInfo *(PHAsset *asset, NSMutableArray *sections) {
        PHFetchedResultsSectionInfo *info = [[PHFetchedResultsSectionInfo alloc] initWithAssetCollection:self.assetCollection date:asset.creationDate options:self.options];
        info.delegate = __self;
        [sections addObject:info];
        return info;
    } completion:^(NSArray<PHFetchedResultsSectionInfo *> *sections) {
//        _mySections = [NSArray arrayWithArray:sections];
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
//            [sections enumerateObjectsUsingBlock:^(PHFetchedResultsSectionInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//                [obj objects];
//            }];
//        });
        @synchronized (self) {
            _mySections = [NSArray arrayWithArray:sections];
            _runningTask = nil;
            PHFetchResultChangeDetails *fetchResultChangeDetails = [PHFetchResultChangeDetails changeDetailsFromFetchResult:previousFetchResult toFetchResult:fetchResult changedObjects:@[]];
            [__self.delegate controller:__self photoLibraryDidChange:fetchResultChangeDetails];
        }
    }];
    
}

- (_PHFetchTask *)findSectionInfoInAssets:(PHFetchResult<PHAsset *> *)assets
                         exists:(void (^)(PHFetchedResultsSectionInfo *sectionInfo))existsBlock
                      notExists:(PHFetchedResultsSectionInfo* (^)(PHAsset *asset, NSMutableArray <PHFetchedResultsSectionInfo *>*sections))notExistsBlock
                     completion:(void (^)(NSArray <PHFetchedResultsSectionInfo *>*sections))completionHandler
{
    _PHFetchTask *task = [_PHFetchTask new];
    
    NSMutableArray *sections = [NSMutableArray array];
    
    __block NSCalendar *calendar = [NSCalendar currentCalendar];
    __block NSInteger previousYear = 0;
    __block NSInteger previousMonth = 0;
    __block NSInteger previousWeek = 0;
    __block NSInteger previousDay = 0;
    __block NSInteger previousHour = 0;
    
    __block PHFetchedResultsSectionInfo *sectionInfo = nil;
    __block PHFetchedResultsSectionKey sectionKey = self.sectionKey;
    
    dispatch_async(_queue, ^{
        [assets enumerateObjectsUsingBlock:^(PHAsset * _Nonnull asset, NSUInteger idx, BOOL * _Nonnull stop) {
            
            if (task.isCanceled) { *stop = YES; }
            
            @autoreleasepool {
                NSDateComponents *dateComponets = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitWeekOfMonth | NSCalendarUnitDay | NSCalendarUnitHour fromDate:asset.creationDate];
                
                NSInteger year = [dateComponets year];
                NSInteger month = [dateComponets month];
                NSInteger week = [dateComponets weekOfMonth];
                NSInteger day = [dateComponets day];
                NSInteger hour = [dateComponets hour];
                
                if (previousYear == year &&
                    (sectionKey >= PHFetchedResultsSectionKeyMonth ? previousMonth == month : YES) &&
                    (sectionKey >= PHFetchedResultsSectionKeyWeek ? previousWeek == week : YES) &&
                    (sectionKey >= PHFetchedResultsSectionKeyDay ? previousDay == day : YES) &&
                    (sectionKey >= PHFetchedResultsSectionKeyHour ? previousHour == hour : YES)) {
                    
                    if (existsBlock) {
                        existsBlock(sectionInfo);
                    }
                    
                } else {
                    
                    if (task.isCanceled) { *stop = YES; }
                    
                    __block BOOL sectionExist = NO;
                    
                    [sections enumerateObjectsUsingBlock:^(PHFetchedResultsSectionInfo * _Nonnull aSectionInfo, NSUInteger idx, BOOL * _Nonnull stop) {
                        if (task.isCanceled) { *stop = YES; }
                        if (aSectionInfo.year == year &&
                            (sectionKey >= PHFetchedResultsSectionKeyMonth ? aSectionInfo.month == month : YES) &&
                            (sectionKey >= PHFetchedResultsSectionKeyWeek ? aSectionInfo.week == week : YES) &&
                            (sectionKey >= PHFetchedResultsSectionKeyDay ? aSectionInfo.day == day : YES) &&
                            (sectionKey >= PHFetchedResultsSectionKeyHour ? aSectionInfo.hour == hour : YES)) {
                            sectionExist = YES;
                            sectionInfo = aSectionInfo;
                            *stop = YES;
                        }
                    }];
                    
                    if (task.isCanceled) { *stop = YES; }
                    
                    if (sectionExist) {
                        
                        if (existsBlock) {
                            existsBlock(sectionInfo);
                        }
                        
                    } else {
                        
                        if (notExistsBlock) {
                            sectionInfo = notExistsBlock(asset, sections);
                        }
                        
                        previousYear = year;
                        previousMonth = month;
                        previousWeek = week;
                        previousDay = day;
                        previousHour = hour;
                        
                    }
                }
            }
        }];
        
        if (!task.isCanceled) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionHandler) {
                    completionHandler(sections);
                }
            });
        }
        
    });
    
    return task;
}

- (NSArray<id<PHFetchedResultsSectionInfo>> *)sections
{
    return (NSArray *)self.mySections;
}

- (PHFetchResult<PHAsset *> *)fetchedObjects
{
    return _fetchResult;
}

- (PHAsset *)assetAtIndexPath:(NSIndexPath *)indexPath
{
    PHFetchedResultsSectionInfo *sectionInfo = self.mySections[indexPath.section];
    return [sectionInfo assetAtIndex:indexPath.item];
}

- (NSIndexPath *)indexPathForAsset:(PHAsset *)asset
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *dateComponets = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitWeekOfMonth | NSCalendarUnitDay | NSCalendarUnitHour fromDate:asset.creationDate];
    
    NSInteger year = [dateComponets year];
    NSInteger month = [dateComponets month];
    NSInteger week = [dateComponets weekOfMonth];
    NSInteger day = [dateComponets day];
    NSInteger hour = [dateComponets hour];
    
    __block PHFetchedResultsSectionInfo *sectionInfo = nil;
    __block NSInteger section;
    __block PHFetchedResultsSectionKey sectionKey = self.sectionKey;
    
    [self.mySections enumerateObjectsUsingBlock:^(PHFetchedResultsSectionInfo * _Nonnull aSectionInfo, NSUInteger idx, BOOL * _Nonnull stop) {
        if (aSectionInfo.year == year &&
            (sectionKey >= PHFetchedResultsSectionKeyMonth ? aSectionInfo.month == month : YES) &&
            (sectionKey >= PHFetchedResultsSectionKeyWeek ? aSectionInfo.week == week : YES) &&
            (sectionKey >= PHFetchedResultsSectionKeyDay ? aSectionInfo.day == day : YES) &&
            (sectionKey >= PHFetchedResultsSectionKeyHour ? aSectionInfo.hour == hour : YES)) {
            section = idx;
            sectionInfo = aSectionInfo;
            *stop = YES;
        }
    }];
    
    if (sectionInfo) {
        NSInteger index = [sectionInfo.objects indexOfObject:asset];
        return [NSIndexPath indexPathForItem:section inSection:index];
    }
    
    return nil;
}

- (NSString *)sectionIndexTitleForSectionName:(NSString *)sectionName
{
    __block NSString *sectionIndexTitle = nil;
    [self.mySections enumerateObjectsUsingBlock:^(PHFetchedResultsSectionInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.name isEqualToString:sectionName]) {
            sectionIndexTitle = obj.indexTitle;
        }
    }];
    return sectionIndexTitle;
}

- (NSInteger)sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)sectionIndex
{
    return 0;
}

- (NSArray<NSString *> *)sectionIndexTitles
{
    NSMutableArray *titles = [NSMutableArray array];
    [self.mySections enumerateObjectsUsingBlock:^(PHFetchedResultsSectionInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.name) {
            [titles addObject:obj.name];
        }
    }];
    return (NSArray *)titles;
}

- (NSInteger)indexForSectionInfo:(PHFetchedResultsSectionInfo *)sectionInfo
{
    return [self.mySections indexOfObject:sectionInfo];
}

- (void)setDateFormateForSectionTitle:(NSString *)dateFormateForSectionTitle
{
    _dateFormateForSectionTitle = [dateFormateForSectionTitle copy];
    [self.mySections enumerateObjectsUsingBlock:^(PHFetchedResultsSectionInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.name = nil;
    }];
}

#pragma mark - PHFetchedResultsSectionInfoDelegate

- (PHFetchedResultsSectionKey)sectionInfoSectionKey
{
    return self.sectionKey;
}

- (NSDateFormatter *)dateFormatter
{
    
    switch (self.sectionInfoSectionKey) {
        case PHFetchedResultsSectionKeyHour:
            _dateFormatter.dateFormat = @"yyyy-MM-W-dd-HH";
            break;
        case PHFetchedResultsSectionKeyDay:
            _dateFormatter.dateFormat = @"yyyy-MM-W-dd";
            break;
        case PHFetchedResultsSectionKeyWeek:
            _dateFormatter.dateFormat = @"yyyy-MM-W";
            break;
        case PHFetchedResultsSectionKeyMonth:
            _dateFormatter.dateFormat = @"yyyy-MM";
            break;
        case PHFetchedResultsSectionKeyYear:
        default:
            _dateFormatter.dateFormat = @"yyyy";
            break;
    }
    
    if (self.dateFormateForSectionTitle) {
        _dateFormatter.dateFormat = self.dateFormateForSectionTitle;
    }
    
    return _dateFormatter;
}

#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance
{
    PHFetchResultChangeDetails *changesDetails = [changeInstance changeDetailsForFetchResult:self.fetchResult];
    if (changesDetails == nil) {
        return;
    }
    self.fetchResult = [changesDetails fetchResultAfterChanges];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate controller:self photoLibraryDidChange:changesDetails];
    });
}
- (NSMutableArray *)sortSessions
{
    NSSortDescriptor *year = [NSSortDescriptor sortDescriptorWithKey:@"self.year" ascending:NO];
    NSSortDescriptor *month = [NSSortDescriptor sortDescriptorWithKey:@"self.month" ascending:NO];
    NSSortDescriptor *week = [NSSortDescriptor sortDescriptorWithKey:@"self.week" ascending:NO];
    NSSortDescriptor *day = [NSSortDescriptor sortDescriptorWithKey:@"self.day" ascending:NO];
    NSSortDescriptor *hour = [NSSortDescriptor sortDescriptorWithKey:@"self.hour" ascending:NO];
    
    return (NSMutableArray *)[self.mySections sortedArrayUsingDescriptors:@[year, month, week, day, hour]];
}

@end
