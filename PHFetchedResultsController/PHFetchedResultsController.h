//
//  PHFetchedResultsController.h
//  PHFetchedResultsController
//
//  Created by 1amageek on 2015/11/30.
//  Copyright © 2015年 Stamp inc. All rights reserved.
//

@import Foundation;
@import PhotosUI;
@import Photos;


typedef NS_ENUM(NSUInteger, PHFetchedResultsSectionKey) {
    PHFetchedResultsSectionKeyYear = 0,
    PHFetchedResultsSectionKeyMonth,
    PHFetchedResultsSectionKeyWeek,
    PHFetchedResultsSectionKeyDay,
    PHFetchedResultsSectionKeyHour
};

typedef NS_OPTIONS(NSUInteger, PHFetchedResultsMediaType) {
    PHFetchedResultsMediaTypeUnknown  = 1 << 0,
    PHFetchedResultsMediaTypeImage  = 1 << 1,
    PHFetchedResultsMediaTypeVideo = 1 << 2,
    PHFetchedResultsMediaTypeAudio = 1 << 3,
};


NS_ASSUME_NONNULL_BEGIN

@protocol PHFetchedResultsSectionInfo;
@protocol PHFetchedResultsControllerDelegate;

@interface PHFetchedResultsController : NSObject

- (instancetype)initWithAssetCollection:(nullable PHAssetCollection *)assetCollection
                             sectionKey:(PHFetchedResultsSectionKey)sectionKey
                              mediaType:(PHFetchedResultsMediaType)mediaType
                         ignoreLocalIDs:(NSArray <NSString *>*)ignoreLocalIDs;

- (BOOL)performFetch:(NSError **)error;

@property (nonatomic, readonly) PHAssetCollection * _Nullable assetCollection;
@property (nonatomic, readonly) PHFetchedResultsSectionKey sectionKey;
@property (nonatomic, readonly) PHFetchedResultsMediaType mediaType;
@property (nullable, nonatomic, readonly) NSString *cacheName;
@property (nullable, nonatomic, readonly) PHFetchResult <PHAsset *>*fetchedObjects;

@property (nonatomic, weak) id <PHFetchedResultsControllerDelegate> delegate;

/* Returns the fetched Asset at a given indexPath.
 */
- (PHAsset *)assetAtIndexPath:(NSIndexPath *)indexPath;

/* Returns the indexPath of a given object.
 */
- (nullable NSIndexPath *)indexPathForAsset:(PHAsset *)asset;

/* Returns the corresponding section index entry for a given section name.
 Default implementation returns the capitalized first letter of the section name.
 Only needed if a section index is used.
 */
- (nullable NSString *)sectionIndexTitleForSectionName:(NSString *)sectionName;


@property (nonatomic) NSArray <NSString *>*ignoreLocalIDs;

@property (nonatomic, readonly) NSArray<NSString *> *sectionIndexTitles;

@property (nullable, nonatomic, readonly) NSArray<id<PHFetchedResultsSectionInfo>> *sections;

@property (nonatomic, copy) NSString *dateFormateForSectionTitle;


- (NSInteger)sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)sectionIndex;


@end

@protocol PHFetchedResultsSectionInfo

/* Name of the section
 */
@property (nonatomic, readonly) NSString *name;

/* Title of the section (used when displaying the index)
 */
@property (nullable, nonatomic, readonly) NSString *indexTitle;

/* Number of objects in section
 */
@property (nonatomic, readonly) NSUInteger numberOfObjects;

/* Returns the array of objects in the section.
 */
@property (nullable, nonatomic, readonly) NSArray *objects;

@end

@interface PHFetchedResultsSectionChangeDetails : NSObject

@property (atomic, strong, readonly, nullable) NSIndexSet *removedIndexes;
@property (atomic, strong, readonly, nullable) NSIndexSet *insertedIndexes;
@property (atomic, strong, readonly, nullable) NSIndexSet *updatedIndexes;

@end

@protocol PHFetchedResultsControllerDelegate <NSObject>

@required
- (void)controller:(PHFetchedResultsController *)controller photoLibraryDidChange:(PHFetchResultChangeDetails *)changesDetails;

@end

NS_ASSUME_NONNULL_END
