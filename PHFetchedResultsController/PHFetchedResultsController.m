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
- (NSCache *)cacheForSectionInfo;
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
@property (nonatomic, readonly) PHAssetCollection * _Nullable assetCollection;
@property (nonatomic, readonly) NSDateComponents *dateComponents;
@property (nonatomic, readwrite) NSUInteger numberOfObjects;
@property (nonatomic, weak) id <PHFetchedResultsSectionInfoDelegate> delegate;

- (instancetype)initWithAssetCollection:(nullable PHAssetCollection *)assetCollection
                                   date:(NSDate *)date
                                options:(PHFetchOptions *)options;

@end

@implementation PHFetchedResultsSectionInfo
{
    NSUInteger _numberOfObjects;
}

- (instancetype)initWithAssetCollection:(nullable PHAssetCollection *)assetCollection
                                   date:(NSDate *)date
                                options:(PHFetchOptions *)options
{
    self = [super init];
    if (self) {
        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
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
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateFormatter *dateFormatter = [self.delegate dateFormatter];
    dateFormatter.calendar = calendar;
    NSDate *date = [calendar dateFromComponents:self.dateComponents];
    _name = [dateFormatter stringFromDate:date];
    return _name;
}

- (NSCache *)cache
{
    return [self.delegate cacheForSectionInfo];
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
    NSCache *cache = [self cache];
    PHFetchResult *cacheResult = [cache objectForKey:name];
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
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    switch (sectionKey) {
        case PHFetchedResultsSectionKeyHour: {
            [dateComponents setYear:self.year];
            [dateComponents setMonth:self.month];
            [dateComponents setWeekOfMonth:self.week];
            [dateComponents setDay:self.day];
            [dateComponents setHour:self.hour];
            startDate = [calendar dateFromComponents:dateComponents];
            [addDateComponents setHour:1];
            endDate = [calendar dateByAddingComponents:addDateComponents toDate:startDate options:0];
        }
            break;
        case PHFetchedResultsSectionKeyDay: {
            [dateComponents setYear:self.year];
            [dateComponents setMonth:self.month];
            [dateComponents setWeekOfMonth:self.week];
            [dateComponents setDay:self.day];
            startDate = [calendar dateFromComponents:dateComponents];
            [addDateComponents setDay:1];
            endDate = [calendar dateByAddingComponents:addDateComponents toDate:startDate options:0];
        }
            break;
        case PHFetchedResultsSectionKeyWeek: {
            [dateComponents setYear:self.year];
            [dateComponents setMonth:self.month];
            [dateComponents setWeekOfMonth:self.week];
            [dateComponents setWeekday:1];
            startDate = [calendar dateFromComponents:dateComponents];
            [addDateComponents setWeekOfMonth:1];
            endDate = [calendar dateByAddingComponents:addDateComponents toDate:startDate options:0];
        }
            break;
        case PHFetchedResultsSectionKeyMonth: {
            [dateComponents setYear:self.year];
            [dateComponents setMonth:self.month];
            startDate = [calendar dateFromComponents:dateComponents];
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
    PHFetchResult <PHAsset *>*result;
    if (self.assetCollection) {
        result = [PHAsset fetchAssetsInAssetCollection:self.assetCollection options:options];
    } else {
        options.includeAssetSourceTypes = PHAssetSourceTypeCloudShared | PHAssetSourceTypeUserLibrary | PHAssetSourceTypeiTunesSynced;
        result = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];
    }
    [cache setObject:result forKey:name];
    
    return result;
}

- (PHAsset *)assetAtIndex:(NSInteger)index
{
    NSInteger count = self.objects.count;
    if (count) {
        if ((self.objects.count - 1) < index) {
            return nil;
        }
        PHAsset *asset = self.objects[index];
        return asset;
    }
    return nil;
}

- (void)removeCache
{
    NSString *name = [self name];
    [[self cache] removeObjectForKey:name];
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
    NSCache *_cache;
    NSDateFormatter *_dateFormatter;
    dispatch_queue_t _queue;
    _PHFetchTask *_runningTask;
}

- (instancetype)initWithAssetCollection:(nullable PHAssetCollection *)assetCollection sectionKey:(PHFetchedResultsSectionKey)sectionKey mediaType:(PHFetchedResultsMediaType)mediaType ignoreLocalIDs:(NSArray <NSString *>*)ignoreLocalIDs
{
    self = [super init];
    if (self) {
        
        _cache = [NSCache new];
        _queue = dispatch_queue_create("phfetchedresultscontroller.queue", DISPATCH_QUEUE_SERIAL);
        
        _dateFormatter = [NSDateFormatter new];
        _assetCollection = assetCollection;
        _sectionKey = sectionKey;
        _mediaType = mediaType;
        
        _mySections = nil;
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
    NSPredicate *predicate;
    if ((_mediaType & PHFetchedResultsMediaTypeImage) == PHFetchedResultsMediaTypeImage) {
        NSPredicate *aPredicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeImage];
        if (predicate) {
            predicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[aPredicate, predicate]];
        } else {
            predicate = aPredicate;
        }
    }
    if ((_mediaType & PHFetchedResultsMediaTypeVideo) == PHFetchedResultsMediaTypeVideo) {
        NSPredicate *aPredicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeVideo];
        if (predicate) {
            predicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[aPredicate, predicate]];
        } else {
            predicate = aPredicate;
        }
    }
    if ((_mediaType & PHFetchedResultsMediaTypeAudio) == PHFetchedResultsMediaTypeAudio) {
        NSPredicate *aPredicate = [NSPredicate predicateWithFormat:@"mediaType == %d", PHAssetMediaTypeAudio];
        if (predicate) {
            predicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[aPredicate, predicate]];
        } else {
            predicate = aPredicate;
        }
    }
    _options.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[_options.predicate, predicate]];
    _options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    if (_assetCollection) {
        self.fetchResult = [PHAsset fetchAssetsInAssetCollection:_assetCollection options:_options];
    } else {
        _options.includeAssetSourceTypes = PHAssetSourceTypeCloudShared | PHAssetSourceTypeUserLibrary | PHAssetSourceTypeiTunesSynced;
        self.fetchResult = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:_options];
    }
    return YES;
}

- (void)setFetchResult:(PHFetchResult<PHAsset *> *)fetchResult
{
    __weak typeof(self) __self = self;
    __block PHFetchResult<PHAsset *> *previousFetchResult = _fetchResult;
    _fetchResult = fetchResult;
    
    // 処理中のタスクがあればキャンセル
    if (_runningTask) {
        [_runningTask cancel];
    }
    
    __block PHFetchResultChangeDetails *fetchResultChangeDetails;
    if (previousFetchResult && _mySections != nil) {
        fetchResultChangeDetails = [PHFetchResultChangeDetails changeDetailsFromFetchResult:previousFetchResult toFetchResult:fetchResult changedObjects:@[]];
        __block NSMutableArray *sections = _mySections.mutableCopy;
        __block NSArray *insertedObjects = fetchResultChangeDetails.insertedObjects ? fetchResultChangeDetails.insertedObjects : @[];
        __block NSArray *removedObjects = fetchResultChangeDetails.removedObjects ? fetchResultChangeDetails.removedObjects : @[];
        NSArray *changeObjects = [insertedObjects arrayByAddingObjectsFromArray:removedObjects];
        
        _runningTask = [self findSectionInfoInAssets:changeObjects sections:sections exists:^(PHFetchedResultsSectionInfo *sectionInfo, PHAsset *asset) {
            [sectionInfo removeCache];
            if ([removedObjects containsObject:asset]) {
                sectionInfo.numberOfObjects --;
            } else if ([insertedObjects containsObject:asset]) {
                sectionInfo.numberOfObjects ++;
            }
        } notExists:^PHFetchedResultsSectionInfo *(PHAsset *asset, NSMutableArray<PHFetchedResultsSectionInfo *> *sections) {
            PHFetchedResultsSectionInfo *info = [[PHFetchedResultsSectionInfo alloc] initWithAssetCollection:self.assetCollection date:asset.creationDate options:self.options];
            info.delegate = __self;
            return info;
        } completion:^(NSArray<PHFetchedResultsSectionInfo *> *sections) {
            @synchronized (self) {
                _mySections = [NSArray arrayWithArray:sections];
                _runningTask = nil;
                [__self.delegate controller:__self photoLibraryDidChange:fetchResultChangeDetails];
            }
        }];
        return;
    }
    
    [_cache removeAllObjects];
    NSMutableArray *sections = [NSMutableArray array];
    _runningTask = [self findSectionInfoInAssets:(NSArray *)_fetchResult sections:sections exists:^(PHFetchedResultsSectionInfo *sectionInfo, PHAsset *asset) {
        sectionInfo.numberOfObjects ++;
    } notExists:^PHFetchedResultsSectionInfo *(PHAsset *asset, NSMutableArray *sections) {
        PHFetchedResultsSectionInfo *info = [[PHFetchedResultsSectionInfo alloc] initWithAssetCollection:self.assetCollection date:asset.creationDate options:self.options];
        info.delegate = __self;
        return info;
    } completion:^(NSArray<PHFetchedResultsSectionInfo *> *sections) {
        @synchronized (self) {
            _mySections = [NSArray arrayWithArray:sections];
            _runningTask = nil;
            [__self.delegate controller:__self photoLibraryDidChange:fetchResultChangeDetails];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [sections enumerateObjectsUsingBlock:^(PHFetchedResultsSectionInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    [obj objects];
                }];
            });
        }
    }];
}

- (_PHFetchTask *)findSectionInfoInAssets:(NSArray<PHAsset *> *)assets
                                 sections:(NSMutableArray *)sections
                                   exists:(void (^)(PHFetchedResultsSectionInfo *sectionInfo, PHAsset *asset))existsBlock
                                notExists:(PHFetchedResultsSectionInfo* (^)(PHAsset *asset, NSMutableArray <PHFetchedResultsSectionInfo *>*sections))notExistsBlock
                               completion:(void (^)(NSArray <PHFetchedResultsSectionInfo *>*sections))completionHandler
{
    _PHFetchTask *task = [_PHFetchTask new];
    
    __block NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
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
                        existsBlock(sectionInfo, asset);
                        if (sectionInfo.numberOfObjects == 0) {
                            @synchronized (task) {
                                [sections removeObject:sectionInfo];
                            }
                        }
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
                            existsBlock(sectionInfo, asset);
                            if (sectionInfo.numberOfObjects == 0) {
                                @synchronized (task) {
                                    [sections removeObject:sectionInfo];
                                }
                            }
                        }
                        
                    } else {
                        
                        if (notExistsBlock) {
                            sectionInfo = notExistsBlock(asset, sections);
                            if (sectionInfo) {
                                @synchronized (task) {
                                    [sections addObject:sectionInfo];
                                }
                            }
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
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
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

- (NSCache *)cacheForSectionInfo
{
    return _cache;
}

#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance
{
    __block PHFetchResultChangeDetails *changesDetails = [changeInstance changeDetailsForFetchResult:self.fetchResult];
    if (changesDetails == nil) {
        return;
    }
    [self performFetch:nil];
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
