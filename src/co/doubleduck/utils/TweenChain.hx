package co.doubleduck.utils;

import haxe.ds.StringMap;
import motion.easing.IEasing;
import motion.actuators.GenericActuator;
import motion.Actuate;
import motion.easing.Linear;

/**
 * ...
 * @author Ido Leshem
 */
class TweenChain
{
	//===================
	//// STATIC MEMBERS
	//===================

	private static var allowNew:Bool = false;
	private static var activeChains:Array<TweenChain> = [];
	private static var count:Int = 0;

	//====================
	//// INSTANCE MEMBERS
	//====================

	private var _obj:Dynamic;
	private var _chains:Array<StringMap<Dynamic>>;
	private var _currIndex:Int;
	private var _id:Int;
	private var _debug:Bool;
	private var _overwrite:Bool;
	private var _activated:Bool;
	private var _runningTween:GenericActuator;


	//====================
	//// STATIC FUNCTIONS
	//====================

	/**
	 * Init and return a chainable tween object.
	 * @param	obj
	 * @return
	 */
	public static function get(obj:Dynamic, overwrite:Bool = false, debug:Bool = false):TweenChain
	{
		TweenChain.allowNew = true;

		var ret:TweenChain = new TweenChain(obj, overwrite, debug);
		TweenChain.activeChains.push( ret );
		ret._id = TweenChain.count;
		TweenChain.count++;

		TweenChain.allowNew = false;

		return ret;
	}

	public static function removeTweens(obj:Dynamic):Void
	{
		var arr = [];
		for (i in TweenChain.activeChains)
		{
			//Actuate.stop(obj, null, false, false);

			if (i._obj == obj)
			{
				if (i._runningTween != null)
				{
					i._runningTween.stop(null, false, false);
				}
				i._chains = [];
				arr.push(i);
			}
		}
		for (i in arr)
		{
			TweenChain.activeChains.remove(i);
		}
	}

	public static function getActiveChains(withoutNulls:Bool = false):Array<TweenChain>
	{
		if (withoutNulls)
		{
			var arr:Array<TweenChain> = [];

			for (i in TweenChain.activeChains)
			{
				if (i._obj != null)
				{
					arr.push(i);
				}
			}
			return arr;
		}

		return TweenChain.activeChains;
	}

	public static function purge():Void
	{
		Actuate.reset();
		TweenChain.activeChains = null;
		TweenChain.activeChains = [];
	}

	//======================
	//// INSTANCE FUNCTIONS
	//======================

	/**
	 * Constructor
	 * @param	obj
	 */
	public function new(obj:Dynamic, overwrite:Bool = false, debug:Bool = false )
	{
		if (TweenChain.allowNew)
		{
			_chains = [];
			_currIndex = 0;
			_obj = obj;
			_debug = debug;
			_overwrite = overwrite;
			_activated = false;
		}
		else
		{
			throw "Wrong call to function new(), use TweenChain.get()";
		}

	}

	/**
	 * Tween a numeric value.
	 * @param	props
	 * @param	duration
	 * @return
	 */
	public function tto(props:Dynamic, duration:Int, ease:IEasing = null, onUpdate:Dynamic = null):TweenChain
	{
		var chain = getNewChainHash();

		if (duration == 0)
		{
			chain.set("type", ChainTypes.APPLY);
		}
		else
		{
			if (ease == null)
			{
				ease = Linear.easeNone;
			}

			chain.set("type", ChainTypes.TWEEN);
			chain.set("duration", duration / 1000);
			chain.set("ease", ease);
			chain.set("onUpdate", onUpdate);
		}

		chain.set("props", props);

		addToQueue(chain);

		return this;
	}

	/**
	 * Wait a while.
	 * @param	duration
	 * @return
	 */
	public function wait(duration:Int = 10):TweenChain
	{
		if (duration == 0)
		{
		return this;
		}

		var chain = getNewChainHash();

		chain.set("duration", duration / 1000);
		chain.set("type", ChainTypes.TIMER);

		addToQueue(chain);

		return this;
	}

	/**
	 * Call a function.
	 * @param	handler
	 * @param	params
	 * @return
	 */
	public function call(handler:Dynamic, params:Array<Dynamic> = null):TweenChain
	{
		var chain = getNewChainHash();

		chain.set("handler", handler);
		chain.set("params", params);
		chain.set("type", ChainTypes.CALL);

		addToQueue(chain);

		return this;
	}

	//===================
	//// PRIVATE METHODS
	//===================

	/**
	 * Adds params to array, and starts the acting sequence if needed.
	 * @param	d
	 */
	private function addToQueue(d:StringMap<Dynamic>)
	{
		_chains.push(d);

		if (!_activated)
		{
			if (d.get("duration") == 0)
			{
				if (d.get("type") == ChainTypes.APPLY)
				{
					Actuate.apply(_obj, d.get("props"));
				}
				else if (d.get("type") == ChainTypes.CALL)
				{
					Reflect.callMethod(d.get("handler"), d.get("handler"), d.get("params"));
				}

			_currIndex++;
			}
			else
			{
				_activated = true;
				act();
			}
		}
	}

	/**
	 * Recursively act until finished.
	 */
	private function act()
	{
		if (_currIndex >= _chains.length)
		{
			destroy();
			return;
		}
		var currChain = _chains[_currIndex];
		_currIndex++;

		_runningTween = null;

		debugTrace(_currIndex + "/" + _chains.length + " :: " + currChain);

		if (currChain.get("type") == ChainTypes.TWEEN)
		{
			if (currChain.get("onUpdate") == null)
			{
				_runningTween = cast Actuate.tween(_obj, currChain.get("duration"), currChain.get("props"), _overwrite)
					.ease(currChain.get("ease"))
					.onComplete(doneActuateTween);
			}
			else
			{
				_runningTween = cast Actuate.tween(_obj, currChain.get("duration"), currChain.get("props"), _overwrite)
					.ease(currChain.get("ease"))
					.onUpdate(currChain.get("onUpdate"), [_obj])
					.onComplete(doneActuateTween);
			}

		}
		else if (currChain.get("type") == ChainTypes.APPLY)
		{
			Actuate.apply(_obj, currChain.get("props"));
			act();
		}
		else if (currChain.get("type") == ChainTypes.TIMER)
		{
			Actuate.timer(currChain.get("duration"))
			.onComplete(act);
		}
		else if (currChain.get("type") == ChainTypes.CALL)
		{
			Reflect.callMethod(currChain.get("handler"), currChain.get("handler"), currChain.get("params"));
			act();
		}
	}

	private function doneActuateTween():Void {
		var currChain = _chains[_currIndex - 1];
		for (prop in Reflect.fields(currChain.get("props"))) {
			var val = Reflect.getProperty(currChain.get("props"), prop);
			Reflect.setProperty(_obj, prop, val);
		}
		act();
	}

	/**
	 * Destroy the instance and cleanup.
	 */
	private function destroy()
	{
		TweenChain.activeChains.remove(this);

		_chains = null;

		if (_obj == null)
		{
			TweenChain.removeTweens(_obj);
		}
	}

	private function debugTrace(d:Dynamic)
	{
		if (_debug)
		{
			trace(d);
		}
	}

	private function getNewChainHash():StringMap<Dynamic>
	{
		var ret:StringMap<Dynamic> = new StringMap<Dynamic>();
		ret.set("type", null);
		ret.set("duration", 0);

		return ret;
	}

}

enum ChainTypes
{
	TWEEN;
	TIMER;
	CALL;
	APPLY;
}