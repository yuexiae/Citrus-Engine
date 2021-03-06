package citrus.sounds {

	import aze.motion.eaze;
	import citrus.sounds.groups.BGMGroup;
	import citrus.sounds.groups.SFXGroup;

	import org.osflash.signals.Signal;

	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.media.SoundMixer;
	import flash.media.SoundTransform;
	import flash.net.URLRequest;
	import flash.utils.Dictionary;
	
	import citrus.sounds.cesound;

	public class SoundManager {
		
		use namespace cesound;
		
		private static var _instance:SoundManager;

		protected var soundsDic:Dictionary;
		
		public var onAllLoaded:Signal;
		public var onSoundComplete:Signal;
		
		public var soundGroups:Vector.<CitrusSoundGroup>;
		
		protected var _masterVolume:Number = 1;
		protected var _masterMute:Boolean = false;

		public function SoundManager() {
			soundsDic = new Dictionary();
			
			onAllLoaded = new Signal();
			onSoundComplete = new Signal(CitrusSoundEvent);
			
			soundGroups = new Vector.<CitrusSoundGroup>();
			
			//default groups
			soundGroups.push(new BGMGroup());
			soundGroups.push(new SFXGroup());
			
			CitrusSound._sm = this;
		}

		public static function getInstance():SoundManager {
			if (!_instance)
				_instance = new SoundManager();

			return _instance;
		}

		public function destroy():void {

			var csg:CitrusSoundGroup;
			for each(csg in soundGroups)
				csg.destroy();
				
			var s:CitrusSound;
			for each(s in soundsDic)
				s.destroy();
				
			soundsDic = null;
			
			onAllLoaded.removeAll();
			onSoundComplete.removeAll();
			
			_instance = null;
		}
		
		/**
		 * register a new sound an initialize its values with the params objects.
		 * accepted parameters are :
		 * - sound : a url, a class or a Sound object.
		 * - volume : the initial volume. the real final volume is calculated like so : volume x group volume x master volume.
		 * - panning : value between -1 and 1 - unaffected by group or master.
		 * - mute : default false, whether to start of muted or not.
		 * - timesToRepeat : default 0. 0 will make the sound loop infinitely.
		 * - group : the groupID of a group, no groups are set by default. default groups ID's are CitrusSoundGroup.SFX (sound effects) and CitrusSoundGroup.BGM (background music)
		 * - triggerSoundComplete : whether to dispatch SoundManager's onSoundComplete signal with a CitrusSoundEvent object on each loop.
		 * - triggerRepeatComplete : whether to dispatch SoundManager's onSoundComplete signal with a CitrusSoundEvent object when all loop ends (when sound as looped as many times as timesToRepeat is set).
		 */
		public function addSound(id:String, params:Object = null):void {
			if (id in soundsDic)
				trace(this, id, "already exists.");
			else
				soundsDic[id] = new CitrusSound(id, params);
		}
		
		/**
		 * add your own custom CitrusSoundGroup here.
		 */
		public function addGroup(group:CitrusSoundGroup):void
		{
			soundGroups.push(group);
		}
		
		/**
		 * removes a group and detaches all its sounds - they will now have their default volume modulated only by masterVolume
		 */
		public function removeGroup(groupID:String):void
		{
			var g:CitrusSoundGroup = getGroup(groupID);
			var i:int = soundGroups.lastIndexOf(g);
			if ( i > -1)
			{
				soundGroups.splice(i, 1);
				g.destroy();
			}
		}
		
		/**
		 * moves a sound to a group - if groupID is null, sound is simply removed from any groups
		 * @param	soundName 
		 * @param	groupID ("BGM", "SFX" or custom group id's)
		 */
		public function moveSoundToGroup(soundName:String, groupID:String = null):void
		{
			var s:CitrusSound;
			var g:CitrusSoundGroup;
			if (soundName in soundsDic)
			{
				s = soundsDic[soundName];
				if (s.cesound::group != null)
					s.cesound::group.removeSound(s);
				if(groupID != null)
				g = getGroup(groupID)
				if (g)
					g.addSound(s);
			}
		}
		
		/**
		 * return group of id 'name' , defaults would be SFX or BGM
		 * @param	name
		 * @return CitrusSoundGroup
		 */
		public function getGroup(name:String):CitrusSoundGroup
		{
			var sg:CitrusSoundGroup;
			for each(sg in soundGroups)
			{
				if (sg.groupID == name)
					return sg;
			}
			return null;
		}
		
		/**
		 * returns a CitrusSound object. you can use this reference to change volume/panning/mute or play/pause/resume/stop sounds without going through SoundManager's methods.
		 */
		public function getSound(name:String):CitrusSound
		{
			if (name in soundsDic)
				return soundsDic[name];
			return null;
		}
		
		/**
		 * helper method to play a sound by its id
		 */
		public function playSound(id:String):void {
			if (id in soundsDic)
				CitrusSound(soundsDic[id]).play();
		}
		
		/**
		 * helper method to pause a sound by its id
		 */
		public function pauseSound(id:String):void {
			if (id in soundsDic)
				CitrusSound(soundsDic[id]).pause();
		}
		
		/**
		 * helper method to resume a sound by its id
		 */
		public function resumeSound(id:String):void {
			if (id in soundsDic)
				CitrusSound(soundsDic[id]).pause();
		}
		
		/**
		 * pauses all playing sounds
		 */
		public function pauseAll():void
		{
			var s:CitrusSound;
			for each(s in soundsDic)
				if (s.isPlaying)
					s.pause();
		}
		
		/**
		 * resumes all paused sounds
		 */
		public function resumeAll():void
		{
			var s:CitrusSound;
			for each(s in soundsDic)
				if (s.isPaused)
					s.resume();
		}
		
		public function stopSound(id:String):void {
			if (id in soundsDic)
			{
				CitrusSound(soundsDic[id]).destroy();
				soundsDic[id] = null;
				delete soundsDic[id];
			}
		}
		
		public function removeSound(id:String):void {
			stopSound(id);
			if (id in soundsDic)
				delete soundsDic[id];
		}
		
		public function removeAllSounds():void {
			var cs:CitrusSound;
			for each(cs in soundsDic)
				removeSound(cs.cesound::name);
		}
		
		public function get masterVolume():Number
		{
			return _masterVolume;
		}
		
		public function get masterMute():Boolean
		{
			return _masterMute;
		}
		
		/**
		 * sets the master volume : resets all sound transforms to masterVolume*groupVolume*soundVolume
		 */
		public function set masterVolume(val:Number):void
		{
			var tm:Number = _masterVolume;
			if (val >= 0 && val <= 1)
				_masterVolume = val;
			else
				_masterVolume = 1;
			
			if (tm != _masterVolume)
			{
				var s:CitrusSound;
				for each(s in soundsDic)
					s.resetSoundTransform();
			}
		}
		
		/**
		 * sets the master mute : resets all sound transforms to volume 0 if true, or 
		 * returns to normal volue if false : normal volume is masterVolume*groupVolume*soundVolume
		 */
		public function set masterMute(val:Boolean):void
		{
			var tm:Boolean = _masterMute;
			_masterMute = val;
			
			if (tm != _masterVolume)
			{
				var s:CitrusSound;
				for each(s in soundsDic)
					s.resetSoundTransform();
			}
		}

		/**
		 * tells if the sound is added in the list.
		 * @param	id
		 * @return
		 */
		public function soundIsAdded(id:String):Boolean {
			return (id in soundsDic);
		}
		
		/**
		 * tells you if a sound is playing or false if sound is not identified.
		 */
		public function soundIsPlaying(id:String):Boolean {
			return (id in soundsDic) ? CitrusSound(soundsDic[id]).isPlaying : false;
		}
		
		/**
		 * tells you if a sound is paused or false if sound is not identified.
		 */
		public function soundIsPaused(id:String):* {
			return (id in soundsDic) ? CitrusSound(soundsDic[id]).isPaused : false;
		}
		
		/**
		 * Cut the SoundMixer. No sound will be heard.
		 */
		public function muteFlashSound(mute:Boolean = true):void {
			
			var s:SoundTransform = SoundMixer.soundTransform;
			s.volume = mute ? 0 : 1;
			SoundMixer.soundTransform = s;
		}

		/**
		 * set volume of an individual sound (its group volume and the master volume will be multiplied to it to get the final volume)
		 */
		public function setVolume(id:String, volume:Number):void {
			if (id in soundsDic)
				soundsDic[id].cesound::volume = volume;
		}
		
		/**
		 * set pan of an individual sound (not affected by group or master
		 */
		public function setPanning(id:String, panning:Number):void {
			if (id in soundsDic)
				soundsDic[id].cesound::panning = panning;
		}
		
		/**
		 * set mute of a sound : if set to mute, neither the group nor the master volume will affect this sound of course.
		 */
		public function setMute(id:String, mute:Boolean):void {
			if (id in soundsDic)
				soundsDic[id].cesound::mute = mute;
		}
		
		/**
		 * Stop playing all the current sounds.
		 * @param except an array of soundIDs you want to preserve.
		 */		
		public function stopAllPlayingSounds(...except):void {
			
			var killSound:Boolean;
			var cs:CitrusSound;
			loop1:for each(cs in soundsDic) {
					
				for each (var soundToPreserve:String in except)
					if (soundToPreserve == cs.name)
						break loop1;
				
				if (soundIsPlaying(cs.name))
					stopSound(cs.name);
			}
		}

		public function tweenVolume(id:String, volume:Number = 0, tweenDuration:Number = 2):void {
			if (soundIsPlaying(id)) {
				var tweenvolObject:Object = {volume:CitrusSound(soundsDic[id]).public::volume};
				
				eaze(tweenvolObject).to(tweenDuration, {volume:volume})
					.onUpdate(function():void {
					CitrusSound(soundsDic[id]).cesound::volume = tweenvolObject.volume;
				});
			} else 
				trace("the sound " + id + " is not playing");
		}

		public function crossFade(fadeOutId:String, fadeInId:String, tweenDuration:Number = 2):void {

			// if the fade-in sound is not already playing, start playing it
			if (!soundIsPlaying(fadeInId))
				playSound(fadeInId);

			tweenVolume(fadeOutId, 0, tweenDuration);
			tweenVolume(fadeInId, 1, tweenDuration);
		}
	}
}
