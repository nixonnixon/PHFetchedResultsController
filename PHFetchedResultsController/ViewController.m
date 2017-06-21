//
//  ViewController.m
//  STPBackgroundTransfer
//
//  Created by 1amageek on 2015/11/19.
//  Copyright © 2015年 Stamp inc. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <PHFetchedResultsControllerDelegate>
@property (nonatomic, strong) PHCachingImageManager *imageManager;
@property CGRect previousPreheatRect;
@property NSMutableArray *ignoreIDs;

@end

@implementation ViewController

static CGSize AssetGridThumbnailSize;

+ (void)loadAssetsLibraryWithComplitionHandler:(void (^)(BOOL authorized))complition
{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    switch (status) {
        case PHAuthorizationStatusNotDetermined:
        case PHAuthorizationStatusRestricted:
        case PHAuthorizationStatusDenied:{
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    complition(YES);
                } else {
                    complition(NO);
                }
            }];
            break;
        }
        case PHAuthorizationStatusAuthorized:
        default:{
            complition(YES);
            break;
        }
    }
}

- (PHCachingImageManager *)imageManager
{
    if (_imageManager) {
        return _imageManager;
    }
    _imageManager = [[PHCachingImageManager alloc] init];
    return _imageManager;
}

- (void)loadView
{
    [super loadView];
    [self.view addSubview:self.collectionView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _ignoreIDs = @[].mutableCopy;
    self.collectionView.backgroundColor = [UIColor whiteColor];
    [self.collectionView registerClass:[GridCell class] forCellWithReuseIdentifier:@"GridCell"];
    [self.collectionView registerClass:[Header class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"Header"];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Set ignore" style:UIBarButtonItemStylePlain target:self action:@selector(ignore:)];
    [self resetCachedAssets];

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateCachedAssets];
}

- (void)ignore:(UIBarButtonItem *)barButtonItem
{
    PHAsset *asset = [self.fetchedResultsController fetchedObjects].firstObject;
    [self.ignoreIDs addObject:asset.localIdentifier];
    [self.fetchedResultsController setIgnoreLocalIDs:self.ignoreIDs];
}

- (PHFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController) {
        return _fetchedResultsController;
    }
    /*PHFetchResult *assetCollections = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum
                                                                               subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary
                                                                               options:nil];
    /PHAssetCollection *assetCollection = assetCollections.firstObject;*/
    
    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.includeAssetSourceTypes = PHAssetSourceTypeiTunesSynced | PHAssetSourceTypeUserLibrary | PHAssetSourceTypeCloudShared;
    PHFetchResult * fetchResult = [PHAsset  fetchAssetsWithOptions:fetchOptions];
    PHAssetCollection *assetCollection = [PHAssetCollection transientAssetCollectionWithAssetFetchResult:fetchResult title:nil];
    
    _fetchedResultsController = [[PHFetchedResultsController alloc] initWithAssetCollection:assetCollection sectionKey:PHFetchedResultsSectionKeyWeek mediaType:PHFetchedResultsMediaTypeImage ignoreLocalIDs:@[]];
    _fetchedResultsController.delegate = self;
    _fetchedResultsController.dateFormateForSectionTitle = @"yyyy.MM.dd";
    
    [_fetchedResultsController performFetch:nil];
    
    return _fetchedResultsController;
}

- (UICollectionView *)collectionView
{
    if (_collectionView) {
        return _collectionView;
    }
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.headerReferenceSize = CGSizeMake(self.view.bounds.size.width, 40);
    layout.sectionInset = UIEdgeInsetsMake(2, 0, 2, 0);
    layout.minimumInteritemSpacing = 2;
    layout.minimumLineSpacing = 2;
    NSInteger n = 4;
    CGFloat width = (self.view.bounds.size.width - layout.sectionInset.left - layout.sectionInset.right - layout.minimumInteritemSpacing * (n - 1))/n;
    layout.itemSize = CGSizeMake(width, width);
    
    CGFloat scale = [UIScreen mainScreen].scale;
    AssetGridThumbnailSize = CGSizeMake(layout.itemSize.width * scale, layout.itemSize.height * scale);
    _collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.allowsMultipleSelection = YES;
    return _collectionView;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return self.fetchedResultsController.sections.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    id <PHFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    Header *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"Header" forIndexPath:indexPath];
    id <PHFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:indexPath.section];
    header.title = [sectionInfo name];
    return header;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PHAsset *asset = [self.fetchedResultsController assetAtIndexPath:indexPath];
    GridCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"GridCell" forIndexPath:indexPath];
    cell.representedAssetIdentifier = asset.localIdentifier;
    cell.backgroundColor = [UIColor grayColor];
    
    if (asset.mediaSubtypes & PHAssetMediaSubtypePhotoLive) {
        UIImage *badge = [PHLivePhotoView livePhotoBadgeImageWithOptions:PHLivePhotoBadgeOptionsOverContent];
        cell.livePhotoBadgeImage = badge;
    }
    
    [self.imageManager requestImageForAsset:asset
                                 targetSize:AssetGridThumbnailSize
                                contentMode:PHImageContentModeAspectFill
                                    options:nil
                              resultHandler:^(UIImage *result, NSDictionary *info) {
                                  // Set the cell's thumbnail image if it's still showing the same asset.
                                  if ([cell.representedAssetIdentifier isEqualToString:asset.localIdentifier]) {
                                      cell.thumbnailImage = result;
                                  }
                                  
                              }];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self resetCachedAssets];
    PHAsset *asset = [self.fetchedResultsController assetAtIndexPath:indexPath];
    [self.ignoreIDs addObject:asset.localIdentifier];
    self.fetchedResultsController.ignoreLocalIDs = self.ignoreIDs;
}

#pragma mark - 

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // Update cached assets for the new visible area.
    
    NSInteger contentOffsetY = (NSInteger)scrollView.contentOffset.y;
    
    if (contentOffsetY % 15 == 0) {
        //NSLog(@"%d", contentOffsetY);
        [self updateCachedAssets];
    }

}

#pragma mark - Asset Caching

- (void)resetCachedAssets {
    [self.imageManager stopCachingImagesForAllAssets];
    self.previousPreheatRect = CGRectZero;
}

- (void)updateCachedAssets {
    BOOL isViewVisible = [self isViewLoaded] && [[self view] window] != nil;
    if (!isViewVisible) { return; }
    
    
    // The preheat window is twice the height of the visible rect.
    CGRect preheatRect = self.collectionView.bounds;
    preheatRect = CGRectInset(preheatRect, 0.0f, -0.5f * CGRectGetHeight(preheatRect));
    
    /*
     Check if the collection view is showing an area that is significantly
     different to the last preheated area.
     */
    CGFloat delta = ABS(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.previousPreheatRect));
    if (delta > CGRectGetHeight(self.collectionView.bounds) / 3.0f) {
        
        // Compute the assets to start caching and to stop caching.
        NSMutableArray *addedIndexPaths = [NSMutableArray array];
        NSMutableArray *removedIndexPaths = [NSMutableArray array];
        
        [self computeDifferenceBetweenRect:self.previousPreheatRect andRect:preheatRect removedHandler:^(CGRect removedRect) {
            NSArray *indexPaths = [self.collectionView aapl_indexPathsForElementsInRect:removedRect];
            [removedIndexPaths addObjectsFromArray:indexPaths];
        } addedHandler:^(CGRect addedRect) {
            NSArray *indexPaths = [self.collectionView aapl_indexPathsForElementsInRect:addedRect];
            [addedIndexPaths addObjectsFromArray:indexPaths];
        }];
        
        NSArray *assetsToStartCaching = [self assetsAtIndexPaths:addedIndexPaths];
        NSArray *assetsToStopCaching = [self assetsAtIndexPaths:removedIndexPaths];
        
        PHImageRequestOptions *imageRequestOptions = [PHImageRequestOptions new];
        imageRequestOptions.resizeMode = PHImageRequestOptionsResizeModeNone;
        imageRequestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
        imageRequestOptions.version = PHImageRequestOptionsVersionOriginal;
        
        // Update the assets the PHCachingImageManager is caching.
        [self.imageManager startCachingImagesForAssets:assetsToStartCaching
                                            targetSize:AssetGridThumbnailSize
                                           contentMode:PHImageContentModeAspectFill
                                               options:imageRequestOptions];
        [self.imageManager stopCachingImagesForAssets:assetsToStopCaching
                                           targetSize:AssetGridThumbnailSize
                                          contentMode:PHImageContentModeAspectFill
                                              options:imageRequestOptions];
        
        // Store the preheat rect to compare against in the future.
        self.previousPreheatRect = preheatRect;
    }
}

- (void)computeDifferenceBetweenRect:(CGRect)oldRect andRect:(CGRect)newRect removedHandler:(void (^)(CGRect removedRect))removedHandler addedHandler:(void (^)(CGRect addedRect))addedHandler {
    if (CGRectIntersectsRect(newRect, oldRect)) {
        CGFloat oldMaxY = CGRectGetMaxY(oldRect);
        CGFloat oldMinY = CGRectGetMinY(oldRect);
        CGFloat newMaxY = CGRectGetMaxY(newRect);
        CGFloat newMinY = CGRectGetMinY(newRect);
        
        if (newMaxY > oldMaxY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY));
            addedHandler(rectToAdd);
        }
        
        if (oldMinY > newMinY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY));
            addedHandler(rectToAdd);
        }
        
        if (newMaxY < oldMaxY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY));
            removedHandler(rectToRemove);
        }
        
        if (oldMinY < newMinY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY));
            removedHandler(rectToRemove);
        }
    } else {
        addedHandler(newRect);
        removedHandler(oldRect);
    }
}

- (NSArray *)assetsAtIndexPaths:(NSArray *)indexPaths {
    if (indexPaths.count == 0) { return nil; }
    NSMutableArray *assets = [NSMutableArray arrayWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths) {
        PHAsset *asset = [self.fetchedResultsController assetAtIndexPath:indexPath];
        [assets addObject:asset];
    }
    
    return assets;
}

- (void)controller:(PHFetchedResultsController *)controller photoLibraryDidChange:(PHFetchResultChangeDetails *)changesDetails
{
    [self.collectionView reloadData];
}

@end
