//
// Flambe - Rapid game development
// https://github.com/aduros/flambe/blob/master/LICENSE.txt

package flambe.platform.flash;

import flash.utils.ByteArray;
import flash.utils.ByteArray;
import flash.geom.Rectangle;
import flash.display3D.Context3D;
import flash.display.BitmapData;
import flash.display.Stage3D;
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.Lib;
import hxsl.Shader;

import haxe.io.Bytes;

import flambe.asset.AssetEntry;
import flambe.display.Graphics;
import flambe.display.Texture;
import flambe.subsystem.RendererSystem;
import flambe.util.Assert;
import flambe.util.Value;
import flambe.util.Promise;

class Stage3DRenderer
    implements InternalRenderer<BitmapData>
{
    public var type (get, null) :RendererType;
    public var maxTextureSize (get, null) :Int;
    public var hasGPU (get, null) :Value<Bool>;

    public var promise : Promise<Bool>;

    public var graphics :InternalGraphics = null;

    public var batcher (default, null) :Stage3DBatcher;
    
#if stage3d_handle_context_loss
    private var rootToData:Map<Stage3DTextureRoot, Dynamic>;
#end

    public function new ()
    {
        _hasGPU = new Value<Bool>(false);
        promise = new Promise<Bool>();
#if stage3d_handle_context_loss
        rootToData = new Map();
        _hasGPU.changed.connect(handleContextLoss, true);
#end

        // Use the first available Stage3D
        var stage = Lib.current.stage;
        for (stage3D in stage.stage3Ds) {
            if (stage3D.context3D == null) {
                stage.addEventListener(Event.RESIZE, onResize);

                stage3D.addEventListener(Event.CONTEXT3D_CREATE, onContext3DCreate);
                stage3D.addEventListener(ErrorEvent.ERROR, onError);

                // The constrained profile is only available in 11.4
                if ((untyped stage3D).requestContext3D.length >= 2) {
                    (untyped stage3D).requestContext3D("auto", "baselineConstrained");
                } else {
                    stage3D.requestContext3D();
                }
                return;
            }
        }
        Log.error("No free Stage3Ds available!");
    }

    inline private function get_type () :RendererType
    {
        return Stage3D;
    }

    inline private function get_maxTextureSize () :Int
    {
        return 2048; // The max supported by BASELINE_CONSTRAINED
    }

    inline private function get_hasGPU () :Value<Bool>
    {
        return _hasGPU;
    }

    public function createTextureFromImage (bitmapData :BitmapData) :Stage3DTexture
    {
        if (_context3D == null) {
            return null; // No Stage3D context yet
        }

        var bitmapData :BitmapData = cast bitmapData;
        var root = new Stage3DTextureRoot(this, bitmapData.width, bitmapData.height);

#if stage3d_handle_context_loss
        rootToData.set(root, bitmapData.clone());
#end

        root.init(_context3D, false);
        root.uploadBitmapData(bitmapData);
        return root.createTexture(bitmapData.width, bitmapData.height);
    }

    public function saveTexture(texture:Texture):Void {
        #if stage3d_handle_context_loss
        var realTexture:Stage3DTexture = cast texture;
        var bitmapData:BitmapData = batcher.readPixels(realTexture.root, 0, 0, realTexture.root.width, realTexture.root.height);
        rootToData.set(realTexture.root, bitmapData);
        #end
    }

    public function createTexture (width :Int, height :Int) :Stage3DTexture
    {
        if (_context3D == null) {
            return null; // No Stage3D context yet
        }

        var root = new Stage3DTextureRoot(this, width, height);
        root.init(_context3D, true);
        return root.createTexture(width, height);
    }

    public function getCompressedTextureFormats () :Array<AssetFormat>
    {
        return [];
    }

    public function createCompressedTexture (format :AssetFormat, data :Bytes) :Stage3DTexture
    {
        Assert.fail(); // Unsupported
        return null;
    }

    public function createGraphics (renderTarget :Stage3DTextureRoot) :Stage3DGraphics
    {
        return new Stage3DGraphics(batcher, renderTarget);
    }

    public function willRender ()
    {
#if flambe_debug_renderer
        trace(">>> begin");
#end
        graphics.willRender();
    }

    public function didRender ()
    {
        graphics.didRender();
#if flambe_debug_renderer
        trace("<<< end");
#end
    }

    private function onContext3DCreate (event :Event)
    {
        var stage3D :Stage3D = event.target;
        _context3D = stage3D.context3D;

        Log.info("Created new Stage3D context", ["driver", _context3D.driverInfo]);
#if flambe_debug_renderer
        _context3D.enableErrorChecking = true;
#end

        batcher = new Stage3DBatcher(_context3D);
        graphics = createGraphics(null);
        onResize(null);
        ShaderGlobals.disposeAll(true);

        // Signal that the GPU context was (re)created
        hasGPU._ = false;
        hasGPU._ = true;
        
        if (!promise.hasResult)
        {
            promise.result = true;
        }
    }

    private function onError (event :ErrorEvent)
    {
        Log.error("Unexpected Stage3D failure!", ["error", event.text]);
    }

    private function onResize (_)
    {
        if (graphics != null && canRender()) {
            var stage = Lib.current.stage;
            batcher.resizeBackbuffer(stage.stageWidth, stage.stageHeight);
            graphics.onResize(stage.stageWidth, stage.stageHeight);
        }
    }

    public function canRender():Bool {
        return _context3D != null && _context3D.driverInfo != "Disposed";
    }

#if stage3d_handle_context_loss
    function handleContextLoss(has:Bool, didHave:Bool) :Void
    {
        if (has && promise.hasResult) {//context was created and it's not the first context
            Log.info("Stage3D GPU context was lost, reuploading textures");
            for (root in rootToData.keys()) {
                root.init(_context3D, false);
                if(Std.is(rootToData.get(root), BitmapData)){
                    root.uploadBitmapData(rootToData.get(root));
                } else {
                    root.uploadByteArray(rootToData.get(root));
                }
            }
        }
    }
#end

    private var _context3D :Context3D;
    private var _hasGPU :Value<Bool>;
}
