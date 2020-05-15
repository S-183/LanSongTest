//
//  LSOTransition.h
//  LanSongEditorFramework
//
//  Created by sno on 2020/3/23.
//  Copyright © 2020 sno. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LSOObject.h"


@class LSOLayer;

NS_ASSUME_NONNULL_BEGIN




@interface LSOTransition : LSOObject




/**
 用一个ae制作的mask json做为转场动画.
 */
-(id)initWithMaskJsonURL:(NSURL *)maskJsonUrl duration:(CGFloat)durationS;

/**
 用图片数组来做为转场动画.
 */
-(id)initWithMaskImageArray:(NSMutableArray *)maskImages duration:(CGFloat)durationS;

/**
 调节时长;
 */
@property (readwrite, assign)CGFloat durationS;







@end

NS_ASSUME_NONNULL_END
