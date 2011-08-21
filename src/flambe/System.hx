//
// Flambe - Rapid game development
// https://github.com/aduros/flambe/blob/master/LICENSE.txt

package flambe;

import flambe.display.MouseEvent;
import flambe.display.Sprite;
import flambe.platform.AppDriver;
import flambe.platform.Storage;
import flambe.util.Signal1;

class System
{
    public static var root (default, null) :Entity;
    public static var driver (default, null) :AppDriver;

    public static var stageWidth (getStageWidth, null) :Int;
    public static var stageHeight (getStageHeight, null) :Int;

    public static var storage (getStorage, null) :Storage;

    public static function init ()
    {
        root = new Entity();

#if flash
        driver = new flambe.platform.flash.FlashAppDriver();
#elseif html
        driver = new flambe.platform.html.HtmlAppDriver();
#elseif amity
        driver = new flambe.platform.amity.AmityAppDriver();
#else
#error "Platform not supported!"
#end
        driver.init(root);
    }

    inline public static function loadAssetPack (url)
    {
        return driver.loadAssetPack(url);
    }

    inline private static function getStageWidth () :Int
    {
        return driver.getStageWidth();
    }

    inline private static function getStageHeight () :Int
    {
        return driver.getStageHeight();
    }

    inline private static function getStorage () :Storage
    {
        return driver.getStorage();
    }
}
