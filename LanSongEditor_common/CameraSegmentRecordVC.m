//
//  CameraSegmentRecordVC.m
//  LanSongEditor_all
//
//  Created by sno on 2018/6/6.
//  Copyright © 2018年 sno. All rights reserved.
//

#import "CameraSegmentRecordVC.h"

#import "DemoUtils.h"
#import "BlazeiceDooleView.h"
#import "FilterTpyeList.h"
#import "SegmentRecordProgressView.h"
#import "DeleteButton.h"
#import "BeautyManager.h"

#import "VideoPlayViewController.h"
#import "StoryMakeStickerImageView.h"
#import "StoryMakeSelectColorFooterView.h"
#import "StoryMakeStickerLabelView.h"
#import "StoryMakeFilterFooterView.h"
#import "MBProgressHUD.h"

/**
 最小的视频时长,如果小于这个, 则视频认为没有录制.
 */
#define MIN_VIDEO_DURATION 2.0f


/**
 定义视频录制的最长时间, 如果超过这个时间,则默认为视频录制已经完成.
 */
#define MAX_VIDEO_DURATION 15.0f

@interface SegmentFile: NSObject

@property (assign, nonatomic) CGFloat duration;
@property (strong, nonatomic) NSString *segmentPath;

@end

@implementation SegmentFile

@end

//LSTODO 只是临时保留, 没有整理;
@interface CameraSegmentRecordVC ()<StoryMakeStickerBaseViewDelegate,StoryMakeSelectColorFooterViewDelegate>
{
    
    NSString *dstPath;
    
    LSOPen *operationPen;  //当前操作的图层
    
    
    FilterTpyeList *filterListVC;
    
    
    LanSongView2  *lansongView;
    DrawPadCameraPreview *drawPadCamera;
    
    BOOL isPaused;
    
    
    NSMutableArray  *segmentArray;  //存放的是当前段的SegmentFile对象.
    
    CGFloat  nvheight;
    CGFloat  totalDuration; //总时长.
    CGFloat  currentSegmentDuration; //当前段的时长;
    
    
    BeautyManager *beautyMng;
    float beautyLevel;
    LSOMVPen *mvPen;
    
    UIView *viewPenRoot; //UI图层上的父类UI;
    DemoProgressHUD *hud;
    LSOVideoOneDo *videoOneDo;
}
@property (strong, nonatomic) SegmentRecordProgressView *progressBar;


@property (strong, nonatomic) DeleteButton *deleteButton;
@property (strong, nonatomic) UIButton *okButton;

@property (strong, nonatomic) UIButton *switchButton;
@property (strong, nonatomic) UIButton *settingButton;
@property (strong, nonatomic) UIButton *recordButton;
@property (strong, nonatomic) UIButton *flashButton;
@property (strong, nonatomic) UIButton *btnClose;
@property (strong, nonatomic) UIButton *btnImg;
@property (strong, nonatomic) UIButton *btnText;
@property (nonatomic, strong) StoryMakeSelectColorFooterView *colorFooterView;  //文字

@property (nonatomic, strong) NSMutableArray <UIView *> *stickerViewArray;
@property (nonatomic, assign) NSInteger stickerTags;

@end

@implementation CameraSegmentRecordVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    hud = [[DemoProgressHUD alloc] init];
    self.view.backgroundColor=[UIColor blackColor];
    [DemoUtils setViewControllerPortrait];
    
    beautyLevel=0;
    beautyMng=[[BeautyManager alloc] init];
    
    self.stickerViewArray = [NSMutableArray array];
    self.stickerTags = 0;
    
    
    //    iphoneX Xs 375 x 812;  (0.5625 则是667);
    //    ihponeXs-r Xs-max  414 x 896 (0.5625 则是736);
    CGSize  fullSize=[[UIScreen mainScreen] bounds].size;
    CGFloat top=0;
    if(fullSize.width * fullSize.height ==375*812){
        fullSize.height=667;
        top=(812-667)/2;
    }else if(fullSize.width * fullSize.height==414*896){
        fullSize.height=736;
        top=(896-736)/2;
    }
    
    CGRect rect=CGRectMake(0, top, fullSize.width, fullSize.height);
    NSLog(@"full size is :%f %f, full radio:%f, 540 rect is:%f",fullSize.width,fullSize.height, fullSize.width/fullSize.height, rect.size.width/rect.size.height);
    
    lansongView = [[LanSongView2 alloc] initWithFrame:rect];
    [self.view addSubview:lansongView];
    
    drawPadCamera=[[DrawPadCameraPreview alloc] initFullScreen:lansongView isFrontCamera:NO];
    drawPadCamera.cameraPen.horizontallyMirrorFrontFacingCamera=YES;
    
    //增加图片图层
    UIImage *image=[UIImage imageNamed:@"small"];
    LSOBitmapPen *bmpPen=    [drawPadCamera addBitmapPen:image];
    bmpPen.positionX=bmpPen.drawPadSize.width-bmpPen.penSize.width/2;
    bmpPen.positionY=bmpPen.penSize.height/2;
    
    // 添加编辑图层
    viewPenRoot = [[UIView alloc] initWithFrame:lansongView.frame];
    [drawPadCamera addViewPen:viewPenRoot isFromUI:YES];
    [self.view addSubview:viewPenRoot];
    
    //开始预览
    [drawPadCamera startPreview];
    [beautyMng addBeauty:drawPadCamera.cameraPen];
    
    
    //初始化其他UI界面.
    [self initView];
    
    segmentArray=[[NSMutableArray alloc] init];
    totalDuration=0;
    currentSegmentDuration=0;
    beautyLevel=0;
    
    [self initView];
}
-(void)drawpadProgress:(CGFloat)currentPts
{
    //更新时间戳.
    if(self.progressBar!=nil){
        [self.progressBar setLastSegmentPts:currentPts];
    }
    
    //走过最小
    if( (totalDuration+ currentPts)>=MIN_VIDEO_DURATION){
        self.okButton.enabled=YES;
        [self.deleteButton setButtonStyle:DeleteButtonStyleNormal];
    }
    //走过最大.则停止.
    if((totalDuration + currentPts)>=MAX_VIDEO_DURATION){
        [self stopSegmentAndFinish];
    }
    
    currentSegmentDuration=currentPts;
}
/**
 开始分段录制
 */
-(void)startSegmentRecord
{
    [_progressBar addNewSegment];
    currentSegmentDuration=0;
    
    [beautyMng addBeauty:drawPadCamera.cameraPen];
    
    __weak typeof (self) weakSelf=self;
    [drawPadCamera setProgressBlock:^(CGFloat progess) {
        dispatch_async(dispatch_get_main_queue(), ^{
             [weakSelf drawpadProgress:progess];
        });
    }];
    
    if(mvPen!=nil){
        [drawPadCamera resumeMVPenAudioPlayer];
    }
    [drawPadCamera startRecord];
}

/**
 结束 当前段录制.
 */
-(void)stopSegment
{
    if(drawPadCamera.isRecording && currentSegmentDuration>0)
    {
        if(mvPen!=nil){
            [drawPadCamera pauseMVPenAudioPlayer];
        }
        [drawPadCamera stopRecord:^(NSString *path) {
            if([LSOFileUtil fileExist:path])
            {
                SegmentFile *file=[[SegmentFile alloc] init];
                file.segmentPath=path;
                file.duration=currentSegmentDuration;
                
                [segmentArray addObject:file];
                totalDuration+=currentSegmentDuration;
            }else{
                NSLog(@"当前段文件不存在....");
            }
        }];
    }
}

/**
 停止当前段,并开始拼接;
 */
-(void)stopSegmentAndFinish
{
    if(drawPadCamera.isRecording && currentSegmentDuration>0)
    {
        __weak typeof (self) weakSelf=self;
        
        [drawPadCamera stopRecord:^(NSString *path) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if([LSOFileUtil fileExist:path])
                {
                    SegmentFile *file=[[SegmentFile alloc] init];
                    file.segmentPath=path;
                    file.duration=currentSegmentDuration;
                    
                    [segmentArray addObject:file];
                    totalDuration+=currentSegmentDuration;
                }else{
                    NSLog(@"当前段文件不存在....");
                }
                [weakSelf concatVideos];
            });
           
        }];
    }
}

/**
 删除 最后一段.
 */
-(void)deleteLastSegment
{
    if(segmentArray.count>0){  //删除最后一个.
        SegmentFile *path=[segmentArray objectAtIndex:segmentArray.count-1];
        
        [segmentArray removeObject:path];
        [LSOFileUtil deleteFile:path.segmentPath];
        
        if(totalDuration>=path.duration){
            totalDuration-=path.duration;
        }
        [_progressBar deleteLastSegment];//删除对应的界面.
    }
    if (segmentArray.count > 0) {
        [_deleteButton setButtonStyle:DeleteButtonStyleNormal];
    } else {
        [_deleteButton setButtonStyle:DeleteButtonStyleDisable];
    }
}
/**
 结束分段录制,
 拼接在一起然后播放;
 工作在主线程;
 */
-(void)concatVideos
{
    if(segmentArray.count>1){  //合成在一起.
        
        NSMutableArray *fileArray = [[NSMutableArray alloc] init];
        for (SegmentFile *data in segmentArray) {
            [fileArray addObject:data.segmentPath];
        }
        //开始拼接起来;
        dstPath=[LSOFileUtil genTmpMp4Path];
        int success = [LSOVideoEditor executeConcatMP4:fileArray dstFile:dstPath];  //耗时很少;
        NSLog(@"executeConcatMP4 = %d",success);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self exportExecute:dstPath];
        });
    }else if(segmentArray.count==1){
        SegmentFile *data=[segmentArray objectAtIndex:0];
        dstPath=data.segmentPath;
        [DemoUtils startVideoPlayerVC:self.navigationController dstPath:dstPath];
    }else{  //为空.
        NSLog(@"segment array is empty");
    }
}

// 导出
-(void)exportExecute:(NSString *)dstPath
{
    //我们的方法是增加一层UI来做
//    UIGraphicsBeginImageContextWithOptions(viewPenRoot.bounds.size, NO, [[UIScreen mainScreen] scale]);
//    [viewPenRoot drawViewHierarchyInRect:viewPenRoot.bounds afterScreenUpdates:NO];
//    UIImage *screenImage = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//
//    WS(weakSelf)
//    LSOVideoAsset *mInfo=[[LSOVideoAsset alloc] initWithPath:dstPath];
//    NSLog(@"fileExistWithURL = %d",[LSOFileUtil fileExistWithURL:mInfo.videoURL]);
//    videoOneDo = [[LSOVideoOneDo alloc] initWithNSURL:mInfo.videoURL];
//    [videoOneDo setCoverPicture:screenImage startTime:mInfo.duration-0.2 endTime:mInfo.duration];
//    [videoOneDo setVideoProgressBlock:^(CGFloat currentFramePts, CGFloat percent) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [weakSelf exportProgress:percent];
//        });
//    }];
//    [videoOneDo setCompletionBlock:^(NSString *video) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [weakSelf exportCompleted:video];
//        });
//    }];
//    [videoOneDo start];
    
    [self exportCompleted:dstPath];
}

-(void)exportProgress:(CGFloat)percent;
{
    [hud showProgress:[NSString stringWithFormat:@"进度:%f",percent]];
}

/**
 导出完成显示
 */
-(void)exportCompleted:(NSString *)videoPath
{
    [hud hide];
    [DemoUtils startVideoPlayerVC:self.navigationController dstPath:videoPath];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}
-(void)viewDidAppear:(BOOL)animated
{
    if(drawPadCamera!=nil){
        [drawPadCamera startPreview];
    }
}
-(void)viewDidDisappear:(BOOL)animated
{
    if (drawPadCamera!=nil) {
        [drawPadCamera stopPreview];
    }
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/**
 回删按钮
 */
- (void)pressDeleteButton
{
    if (_deleteButton.style == DeleteButtonStyleNormal) {//第一次按下删除按钮
        [_progressBar setWillDeleteMode];
        [_deleteButton setButtonStyle:DeleteButtonStyleDelete];
    } else if (_deleteButton.style == DeleteButtonStyleDelete) {//第二次按下删除按钮
        [self deleteLastSegment];
    }
}

/**
 结束录制按钮
 */
- (void)pressOKButton
{
        [self  concatVideos];
}

/**
 按下录制开始
 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_deleteButton.style == DeleteButtonStyleDelete) {//取消删除
        [_deleteButton setButtonStyle:DeleteButtonStyleNormal];
        [_progressBar setNormalMode];
        return;
    }
    
    UITouch *touch = [touches anyObject];
    
    CGPoint touchPoint = [touch locationInView:_recordButton.superview];
    
    if (CGRectContainsPoint(_recordButton.frame, touchPoint)) {
        [self startSegmentRecord];
    } else if (CGRectContainsPoint(_okButton.frame, touchPoint)) {
        [self pressOKButton];
    } else if (CGRectContainsPoint(_deleteButton.frame, touchPoint)) {
        [self pressDeleteButton];
    } else if (CGRectContainsPoint(_btnClose.frame, touchPoint)) {
        [self.navigationController popViewControllerAnimated:YES];
    } else if (CGRectContainsPoint(_deleteButton.frame, touchPoint)) {
        [self pressDeleteButton];
    }
    
}

/**
 松开,停止录制
 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self stopSegment];
}
- (void)initView
{
    nvheight=    self.navigationController.navigationBar.frame.size.height;
    self.progressBar = [SegmentRecordProgressView getInstance];
    self.progressBar.maxDuration=MAX_VIDEO_DURATION;
    
    [DemoUtils setView:_progressBar toOriginY:(DEVICE_SIZE.height*0.75f + nvheight)];
    
    [self.view addSubview:_progressBar ];
    [_progressBar start];
    
    //录制按钮
    CGFloat buttonW = 80.0f;
    self.recordButton = [[UIButton alloc] initWithFrame:CGRectMake(
                                                                   (DEVICE_SIZE.width - buttonW) / 2.0,
                                                                   _progressBar.frame.origin.y + _progressBar.frame.size.height + 10,
                                                                   buttonW, buttonW)];
    
    
    [_recordButton setImage:[UIImage imageNamed:@"video_longvideo_btn_shoot.png"] forState:UIControlStateNormal];
    _recordButton.userInteractionEnabled = NO;
    [self.view addSubview:_recordButton];
    
    //ok按钮
    CGFloat okButtonW = 50;
    self.okButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, okButtonW, okButtonW)];
    [_okButton setBackgroundImage:[UIImage imageNamed:@"record_icon_hook_normal_bg.png"] forState:UIControlStateNormal];
    [_okButton setBackgroundImage:[UIImage imageNamed:@"record_icon_hook_highlighted_bg.png"] forState:UIControlStateHighlighted];
    
    [_okButton setImage:[UIImage imageNamed:@"record_icon_hook_normal.png"] forState:UIControlStateNormal];
    
    [DemoUtils setView:_okButton toOrigin:CGPointMake(self.view.frame.size.width - okButtonW - 10, self.view.frame.size.height - okButtonW - 10)];
    
    [_okButton addTarget:self action:@selector(pressOKButton) forControlEvents:UIControlEventTouchUpInside];
    
    CGPoint center = _okButton.center;
    center.y = _recordButton.center.y;
    _okButton.center = center;
    
    [self.view addSubview:_okButton];
    _okButton.enabled = NO; //刚开始的时候, 不能点击.
    [self.view bringSubviewToFront:self.okButton];
    
    //删除按钮
    self.deleteButton = [DeleteButton getInstance];
    [_deleteButton setButtonStyle:DeleteButtonStyleDisable];
    
    [DemoUtils setView:_deleteButton toOrigin:CGPointMake(15, self.view.frame.size.height - _deleteButton.frame.size.height - 10-nvheight)];
    
    [_deleteButton addTarget:self action:@selector(pressDeleteButton) forControlEvents:UIControlEventTouchUpInside];
    
    
    CGPoint center2 = _deleteButton.center;
    center2.y = _recordButton.center.y;
    _deleteButton.center = center2;
    [self.view addSubview:_deleteButton];
    //美颜按钮
    UIButton *btnBeauty=[[UIButton alloc] init];
    [btnBeauty setTitle:@"美颜+/-" forState:UIControlStateNormal];
    [btnBeauty setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnBeauty.titleLabel.font=[UIFont systemFontOfSize:25];
    btnBeauty.tag=201;
    [self.view addSubview:btnBeauty];
    [btnBeauty addTarget:self action:@selector(doButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    //前置
    UIButton *btnSelect=[[UIButton alloc] init];
    [btnSelect setTitle:@"前置" forState:UIControlStateNormal];
    [btnSelect setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnSelect.titleLabel.font=[UIFont systemFontOfSize:25];
    btnSelect.tag=202;
    [self.view addSubview:btnSelect];
    [btnSelect addTarget:self action:@selector(doButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    
    
    //关闭按钮
    _btnClose=[[UIButton alloc] initWithFrame:CGRectMake(0, 10, 90, 90)];
    [_btnClose setTitle:@"关闭" forState:UIControlStateNormal];
    [_btnClose setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _btnClose.titleLabel.font=[UIFont systemFontOfSize:20];
    _btnClose.tag=301;
    [_btnClose addTarget:self action:@selector(doButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnClose];
    
    //图片按钮
    _btnImg=[[UIButton alloc] initWithFrame:CGRectMake(0, 110, 90, 90)];
    [_btnImg setTitle:@"图片" forState:UIControlStateNormal];
    [_btnImg setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _btnImg.titleLabel.font=[UIFont systemFontOfSize:20];
    _btnImg.tag=302;
    [_btnImg addTarget:self action:@selector(doButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnImg];
    
    // 文字
    _btnText = [[UIButton alloc] initWithFrame:CGRectMake(285, 110, 90, 90)];
    [_btnText setTitle:@"文字" forState:UIControlStateNormal];
    [_btnText setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _btnText.titleLabel.font=[UIFont systemFontOfSize:20];
    _btnText.tag = 303;
    [_btnText addTarget:self action:@selector(doButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnText];
    
    [self.view addSubview:self.colorFooterView]; //文字提出;
}
-(void)doButtonClicked:(UIView *)sender
{
    switch (sender.tag) {
        case 301:  //关闭
            [self.navigationController popViewControllerAnimated:YES];
            break;
        case 201:  //美颜
            if(beautyLevel==0){  //增加美颜
                [beautyMng addBeauty:drawPadCamera.cameraPen];
                beautyLevel+=0.22;
            }else{
                beautyLevel+=0.1;
                [beautyMng setWarmCoolEffect:beautyLevel];
                if(beautyLevel>1.0){ //删除美颜
                    [beautyMng deleteBeauty:drawPadCamera.cameraPen];
                    beautyLevel=0;
                }
            }
            break;
        case 202:
            if(drawPadCamera!=nil){
                [drawPadCamera.cameraPen rotateCamera];
            }
            break;
        case 302:
            if (drawPadCamera  != nil)
            {
                // 添加贴纸
                StoryMakeStickerImageView *stickerImageView = [[StoryMakeStickerImageView alloc] init];
                stickerImageView.tag = 1;
                //增加过来的默认放到drawimageView的中间;
                stickerImageView.frame = CGRectMake(0, 0, SCREENAPPLYHEIGHT(128), SCREENAPPLYHEIGHT(128));
                stickerImageView.center = viewPenRoot.center;
                stickerImageView.contentImageView.image = [UIImage imageNamed:@"small"];
                [viewPenRoot addSubview:stickerImageView];
                
//                UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panImage:)];
//                UIView *view = [[UIView alloc] initWithFrame: lansongView.frame];
//                UIImage *image=[UIImage imageNamed:@"small"];
//                [view addGestureRecognizer:panGesture];
//                LSOViewPen *viewPen = [drawPadCamera addViewPen:view isFromUI:YES];
//                LSOBitmapPen *bmpPen=    [drawPadCamera addBitmapPen:image];
//                NSLog(@"bmpPen.drawPadSize.width=%f",bmpPen.drawPadSize.width);
//                NSLog(@"bmpPen.penSize.width=%f",bmpPen.penSize.width);
//                NSLog(@"bmpPen.penSize.height/2=%f",bmpPen.penSize.height/2);
//                bmpPen.positionX=bmpPen.drawPadSize.width-bmpPen.penSize.width/2;
//                bmpPen.positionY=bmpPen.penSize.height/2 + 100;
                
            }
            break;
        case 303:
            if (drawPadCamera  != nil) {
                // 添加文字
                self.colorFooterView.type = StoryMakeSelectColorFooterViewTypeWriting;
                [self showColorFooterView];
            }
            break;
        default:
            break;
    }
}

- (void)showColorFooterView
{
    self.colorFooterView.hidden = NO;
    [UIView animateWithDuration:0.3
                     animations:^{
                         self.colorFooterView.center = self.view.center;
                     } completion:^(BOOL finished) {
                         [self.colorFooterView updateColorFooterViewInMainView];
                     }];
    
}

- (void)hideColorFooterView
{
    [UIView animateWithDuration:0.3
                     animations:^{
                         self.colorFooterView.center = CGPointMake(self.view.center.x, self.view.center.y + SCREENAPPLYHEIGHT(667));
                     } completion:^(BOOL finished) {
                         self.colorFooterView.hidden = YES;
                     }];
}

#pragma mark - StoryMakeSelectColorFooterViewDelegate

- (void)storyMakeSelectColorFooterViewCloseBtnClicked
{
    [self hideColorFooterView];
}

- (void)storyMakeSelectColorFooterViewConfirmBtnClicked:(NSString *)text font:(UIFont *)font color:(UIColor *)color
{
    self.colorFooterView.center = CGPointMake(self.view.center.x, self.view.center.y + SCREENAPPLYHEIGHT(667));
    self.colorFooterView.hidden = YES;
    
    CGRect rect1 = [text boundingRectWithSize:CGSizeMake(SCREENAPPLYHEIGHT(340), MAXFLOAT)
                                      options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesFontLeading |NSStringDrawingUsesLineFragmentOrigin
                                   attributes:@{NSFontAttributeName:font}
                                      context:nil];
    CGRect rect2 = [text boundingRectWithSize:CGSizeMake(MAXFLOAT, SCREENAPPLYHEIGHT(100))
                                      options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesFontLeading |NSStringDrawingUsesLineFragmentOrigin
                                   attributes:@{NSFontAttributeName:font}
                                      context:nil];
    
    if (rect2.size.width > SCREENAPPLYHEIGHT(340)) {
        rect2.size.width = SCREENAPPLYHEIGHT(340);
    }
    
    StoryMakeStickerLabelView *stickeLabelView = [[StoryMakeStickerLabelView alloc] initWithLabelHeight:CGSizeMake(rect2.size.width, rect1.size.height)];
    stickeLabelView.delegate = self;
    stickeLabelView.tag = self.stickerTags ++;
    stickeLabelView.frame = CGRectMake(0, 0, rect2.size.width + SCREENAPPLYHEIGHT(44), rect1.size.height + SCREENAPPLYHEIGHT(34));
    stickeLabelView.center = CGPointMake(SCREENAPPLYHEIGHT(187.5), SCREENAPPLYHEIGHT(180));
    stickeLabelView.contentLabel.text = text;
    stickeLabelView.contentLabel.font = font;
    stickeLabelView.contentLabel.textColor = color;
    
    [viewPenRoot addSubview:stickeLabelView];
    [self.stickerViewArray insertObject:stickeLabelView atIndex:0];
}

- (void)storyMakeSelectColorFooterViewConfirmBtnClicked:(UIImage *)drawImage
{
    self.colorFooterView.center = CGPointMake(self.view.center.x, self.view.center.y + SCREENAPPLYHEIGHT(667));
    self.colorFooterView.hidden = YES;
    
    UIImageView *drawImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    drawImageView.image = drawImage;
    [viewPenRoot addSubview:drawImageView];
    [self.stickerViewArray insertObject:drawImageView atIndex:0];
}


- (StoryMakeSelectColorFooterView *)colorFooterView
{
    if (!_colorFooterView) {
        _colorFooterView = [[StoryMakeSelectColorFooterView alloc] init];
        _colorFooterView.frame = CGRectMake(0, CGRectGetMaxY(self.view.frame), SCREEN_WIDTH, SCREEN_HEIGHT);
        _colorFooterView.delegate = self;
        _colorFooterView.hidden = YES;
    }
    return _colorFooterView;
}

-(void)dealloc
{
    operationPen=nil;
    
    NSMutableArray *fileArray = [[NSMutableArray alloc] init];
    for (SegmentFile *data in segmentArray) {
        [fileArray addObject:data.segmentPath];
    }
    drawPadCamera=nil;
    
    [LSOFileUtil deleteAllFiles:fileArray];
    segmentArray=nil;
    
    NSLog(@"CameraPenDemoVC  dealloc");
}
///**
// 把多个视频合并
//
// @param filePathArray 视频数组, NSArray中的类型是 (NSString *)
// @param dstPath 用IOS中的AVAssetExportSession导出的.
// @param handler 异步导出的时候, 如果正常则打印
// */
//- (void)concatVideoWithPath:(NSArray *)filePathArray dstPath:(NSString *)dstVideo handle:(void (^)(void))handler;
//{
//    NSError *error = nil;
//    CMTime durationSum = kCMTimeZero;
//
//    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
//    //第一步:拿到所有的assetTrack,放到数组里.
//    for (NSString *filePath in filePathArray)
//    {
//        AVAsset *asset = [AVAsset assetWithURL:[LSOFileUtil filePathToURL:filePath]];
//        if (!asset) {
//            continue;
//        }
//        //加音频
//        AVMutableCompositionTrack *dstAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
//        [dstAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
//                               ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
//                                atTime:durationSum
//                                 error:nil];
//        //加视频
//        AVMutableCompositionTrack *dstVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
//
//
//        [dstVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
//                               ofTrack:[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
//                                atTime:durationSum
//                                 error:&error];
//        if(error!=nil){
//            NSLog(@"error is :%@",error);
//        }
//        //总时间累积;
//        durationSum = CMTimeAdd(durationSum, asset.duration);
//    }
//
//    //get save path
//    NSURL *mergeFileURL =[LSOFileUtil filePathToURL:dstVideo];
//
//    //export
//    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPreset960x540];
//    exporter.outputURL = mergeFileURL;
//    exporter.outputFileType = AVFileTypeMPEG4;
//    exporter.shouldOptimizeForNetworkUse = NO;
//    [exporter exportAsynchronouslyWithCompletionHandler:^(void){
//        switch (exporter.status)
//        {
//            case AVAssetExportSessionStatusCompleted:
//            {
//
//                if(handler!=nil){
//                    handler();
//                }
//            }
//                break;
//            case AVAssetExportSessionStatusFailed:
//                NSLog(@"ExportSessionError--Failed: %@", [exporter.error localizedDescription]);
//                break;
//            case AVAssetExportSessionStatusCancelled:
//                NSLog(@"ExportSessionError--Cancelled: %@", [exporter.error localizedDescription]);
//                break;
//            default:
//                NSLog(@"Export Failed: %@", [exporter.error localizedDescription]);
//                break;
//        }
//    }];
//}




@end

