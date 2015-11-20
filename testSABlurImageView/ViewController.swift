//
//  ViewController.swift
//  testSABlurImageView
//
//  Created by Masaki Horimoto on 2015/10/31.
//  Copyright © 2015年 Masaki Horimoto. All rights reserved.
//

import UIKit


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var imageViewFromLibrary: UIImageView!
    @IBOutlet weak var effectSegControl: UISegmentedControl!
    
    private var effectView : SABlurImageView?                //Effect用View
    var saveImage: UIImage?
    
    enum SABlurEffectStyle : Int {  //BlurEffectのStyleを定義しとく
        case Weak
        case Default
        case Strong
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        imageViewFromLibrary.contentMode = .ScaleAspectFit
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func pressCameraRollButton(sender: AnyObject) {
        pickImageFromLibrary()
    }
    
    /**
     ライブラリから写真を選択する
    */
    func pickImageFromLibrary() {
        guard UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.PhotoLibrary) else {
            return
        }
        
        let controller = UIImagePickerController()
        controller.delegate = self
        controller.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
        
        self.presentViewController(controller, animated: true, completion: nil)
    }
    
    /**
     写真を選択した時に呼ばれる
     
     - parameter picker:おまじないという認識で今は良いと思う
     - parameter didFinishPickingMediaWithInfo:おまじないという認識で今は良いと思う
    */
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo: [String: AnyObject]) {
        
        defer {
            //写真選択後にカメラロール表示ViewControllerを引っ込める動作
            picker.dismissViewControllerAnimated(true, completion: nil)
        }

        //didFinishPickingMediaWithInfo通して渡された情報(選択された画像情報が入っている？)をUIImageにCastする
        guard let originalImage = didFinishPickingMediaWithInfo[UIImagePickerControllerOriginalImage] as? UIImage else {
            return
        }

        //新しい写真の読み込み前にeffectViewを初期化する
        initEffectView()
        
        //そしてそれを宣言済みのimageViewへ放り込む
        imageViewFromLibrary?.image = originalImage
        

    }
    
    /**
     指定したViewに対し、指定した大きさと座標位置で切り取る
     
     - parameter view:切り取り対象View
     - parameter rect:切り取る大きさと座標位置
    */
    func clipView(view: UIView?, rect: CGRect?) -> UIImage? {
        guard let originalView = view else {
            return nil
        }
        
        guard let frameRect = rect else {
            return nil
        }

        // ビットマップ画像のcontextを作成.
        UIGraphicsBeginImageContextWithOptions(frameRect.size, false, 0.0)
        let context: CGContextRef = UIGraphicsGetCurrentContext()!

        //Affine変換
        let affineMoveLeftTop = CGAffineTransformMakeTranslation(-frameRect.origin.x, -frameRect.origin.y)
        CGContextConcatCTM(context, affineMoveLeftTop)
        
        // 対象のview内の描画をcontextに複写する.
        originalView.layer.renderInContext(context)
        
        // 現在のcontextのビットマップをUIImageとして取得.
        let clipedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()
        
        // contextを閉じる.
        UIGraphicsEndImageContext()
        
        return clipedImage

    }

    /**
     エフェクトを適用する
     
     - parameter view:blurをかける対象のView
     - parameter rect:blurをかける位置とサイズ(CGRect)
     - parameter blurLevel:blurレベル
    */
    func addVirtualEffectView(view :UIView?, rect :CGRect?, blurLevel :SABlurEffectStyle?) {
        //print("\(__FUNCTION__) is called!")
        
        //effectViewの内容を一旦初期化する
        initEffectView()
        
        guard let blrlv = blurLevel else {
            return
        }
        
        guard let targetView = view else {
            return
        }
        
        guard let frameRect = rect else {
            return
        }
        
        //blurをかけたい部分をUIImageとして取り出す(=effectImage)
        let effectImage = clipView(view, rect: frameRect)

        
        //blurをかけたい部分(=effectImage)をBlur生成用関数(=SABlurImageView)にセットする
        effectView = SABlurImageView(image: effectImage)
        
        guard let ev = effectView else {
            print("\(__LINE__) \(__FUNCTION__) is called!")
            return
        }

        //Blurの大きさ,座標,形を指定する
        ev.frame = frameRect
        ev.layer.masksToBounds = true
        ev.layer.cornerRadius = 20.0
        
        //blurのかけ具合を指定する
        switch blrlv {
        case .Weak:
            ev.addBlurEffect(25, times: 2)
        case .Default:
            ev.addBlurEffect(50, times: 2)
        case .Strong:
            ev.addBlurEffect(100, times: 3)
        }
        
        //blurがかかったViewを追加する
        targetView.addSubview(ev)
        
    }
    
    /**
     effect用Viewを初期化する
    */
    func initEffectView() {
        effectView?.removeFromSuperview()
        effectView = nil
    }
    
    /**
    sizeとcenter座標の指定からorigin座標を算出する(_=rectを算出する_)関数
     
    - parameter size:算出するrectのsize
    - parameter center:算出するrectのcenter座標
    - returns: sizeとcenterから算出されたorigin座標を含めたrectを返す
    */
    func makeRectFromSizeAndCenter(size :CGSize, center :CGPoint) -> CGRect {
        
        let origin = CGPoint(x: center.x - (size.width) / 2, y: center.y - (size.height) / 2)   //sizeとcenterから座標位置を特定
        let rect = CGRectMake(origin.x, origin.y, size.width, size.height) //blurView用Rect
        
        return rect
    }
    
    /**
     blur Effectメソッド
     
     - parameter effectIndex:effect用Index
    */
    func onClickMySegmentedControl(effectIndex: Int) {
        
        let blurLevels : [SABlurEffectStyle?] = [nil, .Weak, .Default, .Strong]
        let blurLevel = blurLevels[effectIndex]
        
        //blur用ViewのRectを作成する
        let size = CGSize(width: 360, height: 200)      //blur用Viewのサイズ
        let center = imageViewFromLibrary.center   //blur用Viewのcenter位置
        let frameRect = makeRectFromSizeAndCenter(size, center: center) //blur用ViewのRect
        
        addVirtualEffectView(imageViewFromLibrary ,rect: frameRect ,blurLevel: blurLevel)
    }

    /**
     SegControlが押下された時に呼ばれる
    */
    @IBAction func pressSegControl(sender: AnyObject) {
        onClickMySegmentedControl(effectSegControl.selectedSegmentIndex)    //blurEffect実行
    }


}