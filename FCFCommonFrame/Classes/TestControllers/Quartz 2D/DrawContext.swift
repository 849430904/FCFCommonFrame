//
//  DrawContext.swift
//  FCFCommonFrame
//
//  Created by 冯才凡 on 2017/6/26.
//  Copyright © 2017年 com.fcf. All rights reserved.
//

import UIKit

enum DrawingState{
    case begin
    case moved
    case ended
}

//画笔类型
enum DrawType{
    enum PenType {
        case Curve //曲线
        case Line //直线
        case ImaginaryLine //虚线
    }
    case Pentype(PenType)
    enum FormType{
        case Ellipse //椭圆
        case Rect  //矩形
    }
    case Formtype(FormType)
    case Eraser //橡皮擦
    case Text //文本
    case Note //音符
}

//自定义一个数据模型，有image、textview,如果是图片，就txtview为nil，如果是文本，就UIImage为就存之前的图片
class DrawModel:NSObject{
    var ifTextView:Bool = false //是否是文本，默认不是文本而是图片
    var imgData:Data?
    var textData:DrawTextView?
}

//全局单例,用来存储每次画的笔画的相关数据
class DrawManager{
    static let shareInstance = DrawManager()
    private init(){}
    
    var index = -1
    //存储每一笔的相关数据，type:类型;colorStr:笔画颜色或文本文字颜色;strokeWidth笔画宽度，如果是文本就是文本文字最终(缩放之后)大小;points：就是每一笔所经过的点，如果是文本或者图片就存放中心点;imgData:就是图片数据;textStr:文本String,文本就是文字内容,音符就是音符;Width:文本或者图片的最终(缩放之后)宽度,其他类型就为0;Height:文本或图片的最终(缩放之后)高度,其他类型就为0;Rotate:旋转角度,其他类型就为0
    var drawData:[((type:DrawType,colorStr:String,strokeWidth:CGFloat,points:[CGPoint],imgData:Data,textStr:String,Width:CGFloat? ,Height:CGFloat? ,Rotate:CGFloat? ))] = [] //Scale:CGFloat
    //数组保存图片,存放每一笔的图片\文本，
    var modelArr = [DrawModel]()
    //这里就存储文本，key值是对应modelArr中对应的下标，值是图片
    var textViewDic:[Int:DrawTextView] = [:]
    //可以撤回
    var canUndo:Bool{
        get {
            return index != -1
        }
    }
    //可以重做
    var canRedo:Bool{
        get {
            return index + 1 <= modelArr.count
        }
    }
    //添加图片或文本
    func addModel(_ obj:DrawModel){
        if index == -1{
            modelArr.removeAll()
        }
        if obj.ifTextView {
            textViewDic[index+1] = obj.textData!
        }
        modelArr.append(obj)
        index = modelArr.count - 1
    }
    //撤回时候需要的model
    func modelForUndo()->DrawModel?{
        index = index - 1
        if index >= 0 {
            let obj:DrawModel = modelArr[index]
            return obj
        }else{
            index = -1
            return nil
        }
    }
    
    //取出某一步骤的model
    func modelFor(ind:Int)->DrawModel?{
        if ind >= 0 && ind < modelArr.count {
            let obj:DrawModel = modelArr[ind]
            return obj
        }
        return nil
    }
    
    //重做时需要的model
    func modelForRedo()->DrawModel?{
        index = index + 1
        if index <= modelArr.count - 1 {
            return modelArr[index]
        }else{
            if index >= 0 && modelArr.count > 0 {
                index = modelArr.count - 1
                return modelArr[index]
            }
            index = -1
            return nil
        }
    }
    
    var hasDrawed:Bool{
        get {
            return modelArr.count > 0 ? true : false
        }
    }
    //刚进来的时候，获取退出页面时的 最上层的“图片model”，文本则要重头加
    func getTopImg() -> DrawModel? {
        index = modelArr.count - 1
        for obj in modelArr.reversed() {
            if obj.imgData != nil {
                return obj
            }
        }
        return nil
    }
    
    //当撤销到某一步的时候，如果重新开始画了东西，那么之前撤销的笔画都从缓存中移除
    func removeBiggerThanCurrentIndex(){
        if index <= -1 {
            clearArr()
        }else if index <= modelArr.count {
            let n = modelArr.count - (index + 1)
            if n > 0 {
                modelArr.removeLast(n)
                drawData.removeLast(n)
                for (key,_) in textViewDic {
                    if key > index {
                        textViewDic.removeValue(forKey: key)
                    }
                }
            }
        }
    }
    
    //移除某一个文本
    func delete(textView:DrawTextView) {
        var deIndex:Int = -1
        for (key,value) in textViewDic {
            let textData:DrawTextView = value
            if textData.frame == textView.frame  {
                textViewDic.removeValue(forKey: key)
                deIndex = key
                break
            }
        }
        if deIndex >= 0 && deIndex < modelArr.count  {
            modelArr.remove(at: deIndex)
            drawData.remove(at: deIndex)
            self.index = modelArr.count-1
        }
    }
    
    //每缓存一次就应该清理一下数组
    func clearArr(){
        self.modelArr.removeAll()
        self.drawData.removeAll()
        self.index = -1
    }
}

//所有的画画都在这里操作
class DrawContext: UIImageView {
    var boardUndoManager = DrawManager.shareInstance
    var canUndo:Bool{get{return self.boardUndoManager.canUndo}}
    var canRedo:Bool{get{return self.boardUndoManager.canRedo}}
    var hasDraw:Bool{get{return self.boardUndoManager.hasDrawed}}
    
    var brush:BaseBrush? //画笔
    var drawingState:DrawingState? //当前绘画状态
    var realImg:UIImage? //当前图片,它只是一个临时缓存作用
    var drawType:DrawType? //画笔类型
    
    var rotateding:Bool = false
    var selectedDrawTextView:DrawTextView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    //初始化🖌️，设置默认为曲线、黑色、笔宽为1.0
    func initBrush(type:DrawType? = .Pentype(.Curve),color:String? = "000000",width:CGFloat? = 1.0){
        self.drawType = type
        switch self.drawType! {
        case .Pentype(.Curve):
            print("曲线")
            brush = PencilBrush()
            brush?.strokeWidth = width!
            brush?.strockColor = color!
            
        case .Pentype(.Line):
            print("直线")
            brush = LineBrush()
            brush?.strokeWidth = width!
            brush?.strockColor = color!
        case .Pentype(.ImaginaryLine):
            print("虚线")
            brush = ImaginaryLineBrush()
            brush?.strokeWidth = width!
            brush?.strockColor = color!
        case .Formtype(.Rect):
            print("矩形")
            brush = RectBrush()
            brush?.strokeWidth = width!
            brush?.strockColor = color!
        case .Formtype(.Ellipse):
            print("椭圆")
            brush = EllipseBrush()
            brush?.strokeWidth = width!
            brush?.strockColor = color!
        case .Eraser:
            print("橡皮擦")
            brush = EraserBrush()
            brush?.strokeWidth = width!
            brush?.strockColor = color!
        case .Note:
            print("音符")
            brush = WordBrush()
            brush?.strockColor = color!
            brush?.strokeWidth = width!
        case .Text:
            print("文本")
            brush = TextBrush()
            brush?.strockColor = color!
            brush?.strokeWidth = width!
        }
    }
}

//对外接口
extension DrawContext{
    //颜色改变了
    func changeBrushColor(color:String) {
        if let brush = self.brush {
            brush.strockColor = color
        }
    }
    
    //画笔大小改变了
    func changeBrushSize(size:CGFloat){
        if let brush = self.brush {
            brush.strokeWidth = size
        }
    }
    
    //如果切换为其他的就隐藏文本的编辑及UI功能
    func hideTextViewUIMsg(){
        for i in 0..<self.subviews.count {
            let view = self.subviews[i]
            if view.classForKeyedArchiver == DrawTextView.classForCoder() {
                let textView:DrawTextView = view as! DrawTextView
                textView.layer.borderWidth = 0.0
                textView.layer.borderColor = UIColor.clear.cgColor
            }
        }
    }
    //如果切换为文本就显示文本的编辑及UI功能
    func showTextVIewUIMsg(){
        for i in 0..<self.subviews.count {
            let view = self.subviews[i]
            if view.classForKeyedArchiver == DrawTextView.classForCoder() {
                var textView:DrawTextView = view as! DrawTextView
                perfectTextView(textView: &textView)
            }
        }
    }
    
    //每次选中文本就将textview的基本信息设置一下
    func perfectTextView(textView:inout DrawTextView){
        textView.backgroundColor = UIColor.clear
        textView.layer.cornerRadius = 4
        textView.layer.masksToBounds = true
    }
    
    //是否可重做
    func canForward()->Bool{
        return self.canRedo
    }
    //是否可撤销
    func canBack()->Bool{
        return self.canUndo
    }
    //撤销
    func undo() {
        if self.canUndo == false {
            return
        }
        if let obj = self.boardUndoManager.modelForUndo(){
            if obj.ifTextView {
                //如果是文本，那当前文本就不移除，只需要图片显示对应的img就行,然后将当前文本之后的所有文本移除掉
                if let imgData = obj.imgData {
                    let img = NSKeyedUnarchiver.unarchiveObject(with: imgData) as! UIImage
                    self.image = img
                    self.realImg = self.image
                }else{
                    self.image = nil
                    self.realImg = nil
                }
                if let textData = self.boardUndoManager.textViewDic[(self.boardUndoManager.index + 1)] {
                    //是文本,将其移除
                    let textView = textData as DrawTextView
                    for view in self.subviews {
                        if view.frame == textView.frame {
                            view.removeFromSuperview()
                        }
                    }
                }
            }else{
                //如果当前是图片，则需要判断刚才移除的步骤是否是文本,如果是文本就不动图片，只需将文本移除就好
                if let textData = self.boardUndoManager.textViewDic[(self.boardUndoManager.index + 1)] {
                    //是文本,将其移除
                    let textView = textData as DrawTextView
                    for view in self.subviews {
                        if view.frame == textView.frame {
                            view.removeFromSuperview()
                        }
                    }
                }else if let imgData = obj.imgData {
                    //图片
                    let img = NSKeyedUnarchiver.unarchiveObject(with: imgData) as! UIImage
                    self.image = img
                    self.realImg = self.image
                }
            }
        }else{
            //如果第0个是文本
            if let textData = self.boardUndoManager.textViewDic[(self.boardUndoManager.index + 1)] {
                //是文本,将其移除
                let textView = textData as DrawTextView
                for view in self.subviews {
                    if view.frame == textView.frame {
                        view.removeFromSuperview()
                    }
                }
            }
            self.image = nil
            self.realImg = nil
        }
        //已经撤销到第一张
        if self.boardUndoManager.index == -1 {
            //
        }
    }
    //重做
    func redo() {
        if self.canRedo == false {
            return
        }
        if let obj = self.boardUndoManager.modelForRedo() {
            if obj.ifTextView {
                //文本
                let textView = obj.textData! as DrawTextView
                //添加过的就不再添加
                var hasAdd:Bool = false
                for view in self.subviews {
                    if view.frame == textView.frame {
                        hasAdd = true
                        break
                    }
                }
                if !hasAdd {
                    self.addSubview(textView)
                }
                
            }else if let imgData = obj.imgData{
                let img = NSKeyedUnarchiver.unarchiveObject(with: imgData) as! UIImage
                self.image = img
                self.realImg = self.image
            }
        }
        
        //已经前进到最后一张图片
        if self.boardUndoManager.index == self.boardUndoManager.modelArr.count - 1 {
            //
        }
    }
    
    //在离开当前页面的时候，将之前撤销的东西彻底清掉，如果没有离开当前页面，但是撤销完了之后重新画画，那也把之前撤销的彻底清掉
    func removeUselessSave(){
        self.boardUndoManager.removeBiggerThanCurrentIndex()
    }
    
    //还原原来的图层样式，将最顶层的图片取出来作为realImg，再将文本加进来。
    func restoreDraw(){
        if self.hasDraw == false{
            return
        }
        
        if let obj = self.boardUndoManager.getTopImg() {
            if let imgData = obj.imgData {
                let img = NSKeyedUnarchiver.unarchiveObject(with: imgData) as! UIImage
                self.image = img
                self.realImg = self.image
            }
        }
        
        //将文本加上去，这里虽然不是按顺序加的，但是在modelArr中是有顺序记录的
        
        for (_,value) in self.boardUndoManager.textViewDic {
            let textData:DrawTextView = value
            print(textData.frame)
            self.addSubview(textData)
        }
    }
}

extension DrawContext{
    //这个方法只适用于直线、曲线、椭圆、矩形、橡皮擦等类型
    func drawShapeing(){
        if let brush = self.brush {
            //创建一个位图上下文
            UIGraphicsBeginImageContext(self.bounds.size)
            //初始化context（宽度、颜色、圆润度）
            let context = UIGraphicsGetCurrentContext()
            UIColor.clear.setFill()
            UIRectFill(self.bounds)
            context?.setLineCap(CGLineCap.round)
            context?.setLineWidth(brush.strokeWidth)
            
            context?.setStrokeColor(UIColor.haxString(hex: brush.strockColor).cgColor)
            
            //把图片画进去
            if let img = self.realImg { //
                img.draw(in: self.bounds)
            }
            
            //设置brush的基本属性
            brush.drawInContext(context: context!)
            context!.strokePath() //
            
            //从当前的context中得到Image，如果是ended状态或者需要支持连续不断的绘图，则将Image保存到bgImg里
            let previewImage = UIGraphicsGetImageFromCurrentImageContext() //拿到当前图片
            if self.drawingState == .ended || brush.supportedContinnuousDrawing() {
                self.realImg = previewImage //
            }
            
            UIGraphicsEndImageContext()
            
            //实时显示当前的绘制状态，并记录最后一个点
            self.image = previewImage
            if self.drawingState == .ended {
                let imgData = NSKeyedArchiver.archivedData(withRootObject: self.image!)
                //将图片存进数组中
                let obj = DrawModel()
                obj.imgData = imgData
                self.boardUndoManager.addModel(obj)
                //将点集存进数组
                
                self.boardUndoManager.drawData.append(((type: self.drawType!, colorStr: brush.strockColor, strokeWidth: brush.strokeWidth, points: brush.pointsArr, imgData:imgData,textStr:"", Width: 0, Height: 0, Rotate: 0)))
            }
            brush.lastPoint = brush.endPoint
        }
    }
    
    //文本
    func drawText(){
        if let brush = self.brush {
            //默认3行
            let twidth:CGFloat = (self.frame.width - (brush.beginPoint?.x)!) > 200 ? 200 : (self.frame.width - (brush.beginPoint?.x)!)
            var drawtextView = DrawTextView(frame: CGRect(x: (brush.beginPoint?.x)!, y: (brush.beginPoint?.y)!, width: twidth, height: 24 * 3),index:self.boardUndoManager.index + 1,color:brush.strockColor,strokewidth:brush.strokeWidth)
            perfectTextView(textView: &drawtextView)
            drawtextView.btnDelegate = self
            self.addSubview(drawtextView)
        }
    }
    
    //文字
    func drawWord() {
        if let brush = self.brush {
            //开启图片上下文
            UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, UIScreen.main.scale)
            //图形重绘
            self.draw(self.bounds)
            let fontsize:CGFloat = brush.strokeWidth
            //水印文字属性
            let att = [NSForegroundColorAttributeName:UIColor.haxString(hex: brush.strockColor),NSFontAttributeName:UIFont.systemFont(ofSize: fontsize),NSBackgroundColorAttributeName:UIColor.clear] as [String : Any]
            //水印文字大小
            let text = NSString(string: "♪ ♩ ♫ ♬ ¶ ‖♭ ♯ § ∮")
            let textSize = text.boundingRect(with: CGSize(width: 320, height: 999), options: .usesLineFragmentOrigin, attributes: [NSFontAttributeName:UIFont.systemFont(ofSize: fontsize)], context: nil)
            let textW:CGFloat = textSize.width;
            let textH:CGFloat = textSize.height;
            
            //绘制文字 ,文字显示的位置，要在textview的适当位置
            text.draw(in: CGRect(x:(brush.beginPoint?.x)!-(fontsize/2.0),y:(brush.beginPoint?.y)!-(fontsize/2.0),width:textW + 10,height:textH + 10), withAttributes: att)
            //从当前上下文获取图片
            let image = UIGraphicsGetImageFromCurrentImageContext()
            //关闭上下文
            UIGraphicsEndImageContext()
            self.image = image
            
            self.realImg = image
            
            let imgData = NSKeyedArchiver.archivedData(withRootObject: self.image!)
            //将图片存进数组中
            let obj = DrawModel()
            obj.imgData = imgData
            self.boardUndoManager.addModel(obj)
            //将点集存进数组
            
            self.boardUndoManager.drawData.append(((type: self.drawType!, colorStr: brush.strockColor, strokeWidth: brush.strokeWidth, points: brush.pointsArr, imgData:imgData,textStr:"", Width: 0, Height: 0, Rotate: 0)))
        }
    }
}

extension DrawContext:UITextViewDelegate,DrawTextViewDelegate{
    func drawTextViewRotated(drawTextView:DrawTextView,index:Int,touchPoint:CGPoint){
        let target = drawTextView.center
        
        let angle = atan2(touchPoint.y-target.y, touchPoint.x-target.x)
        drawTextView.transform = CGAffineTransform(rotationAngle: angle)
    }
    func drawTextViewPullToNewPosition(drawTextView: DrawTextView,index:Int, oldCenterPoint: CGPoint, newCenterPoint: CGPoint) {
        
    }
    
    func drawTextViewRotated(drawTextView:DrawTextView,index:Int,rotated:Bool){
        self.rotateding = rotated
        if rotated {
            self.selectedDrawTextView = drawTextView
        }else{
            self.selectedDrawTextView = nil
        }
    }

    func drawTextViewDeleteBtnCLicked(drawTextView:DrawTextView,index:Int){
        drawTextView.textView.resignFirstResponder()
        drawTextView.removeFromSuperview() //
        //移除。同时也需要从数组中移除，待续
        self.boardUndoManager.delete(textView: drawTextView)
    }
    
    func drawTextViewSureBtnCLicked(drawTextView:DrawTextView,index:Int,textStr:String){
        drawTextView.textView.resignFirstResponder()
        
        if textStr == "" {
            drawTextView.removeFromSuperview()
            return
        }
        
        //修正framw
//        let fontsize:CGFloat = (brush?.strokeWidth)!
//        let text = NSString(string: textView.text)
//        let textSize = text.boundingRect(with: CGSize(width: textView.frame.size.width, height: 999), options: .usesLineFragmentOrigin, attributes: [NSFontAttributeName:UIFont.systemFont(ofSize: fontsize)], context: nil)
//        let textW:CGFloat = textSize.width;
//        let textH:CGFloat = textSize.height;
//        textView.frame = CGRect(x: textView.frame.origin.x, y: textView.frame.origin.y, width: (textW + 10 > 34 ? (textW + 10) : 34), height: (textH + 10 > 34 ? (textH + 10) : 34))
        
        //将图片存进数组中
        //            let dataDTView = NSKeyedArchiver.archivedData(withRootObject: textView)
        var imgData:Data? = nil
        if let img = self.image {
            imgData = NSKeyedArchiver.archivedData(withRootObject: img)
        }
        let obj = DrawModel()
        obj.textData = drawTextView
        obj.imgData = imgData
        obj.ifTextView = true
        self.boardUndoManager.addModel(obj)
        let twidth:CGFloat = (self.frame.width - (self.brush!.beginPoint?.x)!) > 200 ? 200 : (self.frame.width - (self.brush!.beginPoint?.x)!)
        //将点集存进数组
        self.boardUndoManager.drawData.append(((type: self.drawType!, colorStr: (self.brush?.strockColor)!, strokeWidth: (self.brush?.strokeWidth)!, points: (self.brush?.pointsArr)!, imgData:Data(),textStr:textStr, Width: twidth, Height: 200, Rotate: 0))) //(textW + 10) textH + 10
    }
}

//处理手指触碰
extension DrawContext{
    
    //统一调用画图方法,解析xml的同时，调用这个方法就OK了
    func drawPoints(state:DrawingState,point:CGPoint) {
        self.drawingState = state
        if let brush = self.brush  {
            switch state {
            case .begin:
                brush.pointsArr.removeAll()
                brush.lastPoint = nil
                brush.beginPoint = point
                brush.endPoint = brush.beginPoint
                if brush.classForKeyedArchiver == PencilBrush.classForCoder() || brush.classForKeyedArchiver == EraserBrush.classForCoder() || brush.classForKeyedArchiver == ImaginaryLineBrush.classForCoder() || brush.classForKeyedArchiver == LineBrush.classForCoder() || brush.classForKeyedArchiver == RectBrush.classForCoder() || brush.classForKeyedArchiver == EllipseBrush.classForCoder() {
                    
                    brush.pointsArr.append(point)
                    self.drawShapeing()
                }else if brush.classForKeyedArchiver == TextBrush.classForCoder() {
                    //文本
                    brush.pointsArr.append(point) //原点位置
                    self.drawText()
                }else if brush.classForKeyedArchiver == WordBrush.classForCoder(){
                    //文字
                    brush.pointsArr.append(point) //原点位置
                    drawWord()
                }
                break
            case .moved:
                brush.endPoint = point
                if brush.classForKeyedArchiver == PencilBrush.classForCoder() || brush.classForKeyedArchiver == EraserBrush.classForCoder() || brush.classForKeyedArchiver == ImaginaryLineBrush.classForCoder() || brush.classForKeyedArchiver == LineBrush.classForCoder() || brush.classForKeyedArchiver == RectBrush.classForCoder() || brush.classForKeyedArchiver == EllipseBrush.classForCoder() {
                    
                    brush.pointsArr.append(point)
                    self.drawShapeing()
                }else if brush.classForKeyedArchiver == TextBrush.classForCoder() {
                    
                }else if brush.classForKeyedArchiver == WordBrush.classForCoder(){
                    
                }
                break
            case .ended:
                brush.endPoint = point
                if brush.classForKeyedArchiver == PencilBrush.classForCoder() || brush.classForKeyedArchiver == EraserBrush.classForCoder() || brush.classForKeyedArchiver == ImaginaryLineBrush.classForCoder() || brush.classForKeyedArchiver == LineBrush.classForCoder() || brush.classForKeyedArchiver == RectBrush.classForCoder() || brush.classForKeyedArchiver == EllipseBrush.classForCoder() {
                    
                    brush.pointsArr.append(point)
                    self.drawShapeing()
                }else if brush.classForKeyedArchiver == TextBrush.classForCoder() {
                    
                }else if brush.classForKeyedArchiver == WordBrush.classForCoder(){
                    
                }
                break
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let point:CGPoint = (touches.first?.location(in: self))!
        if !self.rotateding{
            //每次绘画的时候将之前撤销的清理掉
            removeUselessSave()
            self.drawPoints(state: .begin, point: point)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let point:CGPoint = (touches.first?.location(in: self))!
        if !self.rotateding{
            self.drawPoints(state: .moved, point: point)
        }else if let drawTV = self.selectedDrawTextView {
            if !drawTV.textView.frame.contains(point) {
                let target = drawTV.center
                let angle = atan2(point.y-target.y, point.x-target.x)
                drawTV.transform = CGAffineTransform(rotationAngle: angle)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let point:CGPoint = (touches.first?.location(in: self))!
        if !self.rotateding{
            self.drawPoints(state: .ended, point: point)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let brush = self.brush {
            brush.endPoint = nil
        }
    }
}

