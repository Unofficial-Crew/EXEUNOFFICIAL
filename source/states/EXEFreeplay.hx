package states;

import backend.WeekData;
import backend.Song;
import backend.Highscore;
import backend.Language;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.addons.display.FlxBackdrop;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.math.FlxMath;
import flixel.util.FlxSave;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.util.FlxTimer;

import openfl.display.BitmapData;
import openfl.filters.ShaderFilter;

import shaders.PincushionShader;

typedef ExeSongInfo = {
	var songName:String;
	var coverFile:String;
	var title:String;
	var exeLabel:String;
	var transitionShape:String;
	var bgColor:Array<Int>;
	@:optional var alt:ExeSongInfo;
	@:optional var minigame:Bool;
}

typedef ExeSongEntry = {
	var week:Int;
	var folder:String;
	var songs:Array<ExeSongInfo>;
}

@:allow(backend.BurningBot)
class EXEFreeplay extends MusicBeatState
{
	#if mobile var COOLDOWN_TIMER:Float = 0.15; #end
	
	var songEntries:Array<ExeSongEntry> = [];

	var bgChecker:FlxBackdrop;
	var bgSonic:FlxBackdrop;
	var bgCam:FlxCamera;
	var pincushionShader:PincushionShader;
	var verticalLine:FlxSprite;
	var degradado:FlxSprite;
	var spikesUp:FlxBackdrop;
	var freeBoxes:FlxTypedGroup<FlxSprite>;
	var covers:FlxTypedGroup<FlxSprite>;
	var exeTexts:FlxTypedGroup<FlxText>;
	var intendedColor:Int;

	var charText:FlxText;
	var songTexts:FlxTypedGroup<FlxText>;
	var altArrow:FlxSprite;

	var staticScreens:FlxTypedGroup<FlxSprite>;
	var staticTween:FlxTween;

	var cardGroups:Array<FlxTypedGroup<FlxSprite>> = [];
	var cardGroupsLayer:FlxTypedGroup<FlxTypedGroup<FlxSprite>>;
	var cardPositions:Array<FlxObject> = [];
	
	public static var selectedBox:Int = 0;
	var changeCooldown:Float = 0;
	var choosingSong:Bool = false;
	var songSelector:Int = 0;
	var songScrollOffset:Int = 0;
	var activeSongCount:Int = 0;
	var boxWidth:Float = 0;
	var centerX:Float = 0;
	var centerY:Float = 0;
	var previousWindowName:String = "";

	static final ARROW_ICONS:Array<String> = ["^", "<", "v", ">"];
	var currentArrowIndex:Int = 0;
	var arrowTimer:FlxTimer;

	var curDifficulty:Int = -1;
	static var lastDifficultyName:String = '';

	var scoreText:FlxText;
	var rankText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;
	
	var stopMusicPlay:Bool = false;
	
	var holdCheck:Float = 0;
	#if !final
	public static var inDevMode:Bool = false;
	#end

	public static var maniaUnlock:Bool = false;

	override function create()
	{
		if (FlxG.stage?.window != null)
			previousWindowName = FlxG.stage.window.title;

		Paths.clearStoredMemory();

		PlayState.isStoryMode = false;
		Mods.loadTopMod();
		WeekData.reloadWeekFiles(false);

		backend.BurningBot.resetFreeplayState();

		buildSongList();
		if (selectedBox < 0 || selectedBox >= songEntries.length) selectedBox = 0;

		if (maniaUnlock && FlxG.save.data.unlockManiaOnce == null) new FlxTimer().start(0.6, (_) -> maniaNotif());
		else maniaUnlock = false;

		covers = new FlxTypedGroup<FlxSprite>();
		freeBoxes = new FlxTypedGroup<FlxSprite>();
		exeTexts = new FlxTypedGroup<FlxText>();
		songTexts = new FlxTypedGroup<FlxText>();

		final langFont = Paths.font(Language.getFontForLanguage());
		final charSize = Language.cjkSize(42);
		charText = new FlxText(0, 5, FlxG.width, "", charSize);
		charText.setFormat(Paths.font('SonicCD.ttf'), charSize, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		charText.antialiasing = false;
		charText.borderSize = 3;
		
		loadBgSonic();
		loadBgChecker();
		loadVerticalLine();

		staticScreens = new FlxTypedGroup<FlxSprite>();
		cardGroups = [];
		cardPositions = [];
		cardGroupsLayer = new FlxTypedGroup<FlxTypedGroup<FlxSprite>>();
		add(cardGroupsLayer);

		loadDegradado();
		loadSpikesUp();
		loadVignette();

		add(exeTexts);
		if (songEntries.length > 0)
		{
			final uiSize = Language.cjkSize(32);
			rankText = new FlxText(0, 0, 0, Language.get('freeplay.rank', 'RANK') + ': -', uiSize);
			rankText.setFormat(langFont, uiSize, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			rankText.antialiasing = false;
			rankText.borderSize = 3;
			rankText.y = FlxG.height - rankText.height - 15;

			scoreText = new FlxText(0, 0, 0, Language.get('freeplay.score', 'SCORE') + ': 0', uiSize);
			scoreText.setFormat(langFont, uiSize, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			scoreText.antialiasing = false;
			scoreText.borderSize = 3;
			scoreText.y = rankText.y - scoreText.height - 25;

			add(scoreText);
			add(rankText);

			missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
			missingTextBG.alpha = 0.6;
			missingTextBG.visible = false;
			add(missingTextBG);

			missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
			missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			missingText.scrollFactor.set();
			missingText.visible = false;
			add(missingText);

			add(charText);
			add(songTexts);

			altArrow = makeAltArrow();
			add(altArrow);
		}

		createBoxesAndCovers();
		backend.BurningBot.fixInitialCover(this);

		if (songEntries.length == 0)
		{
			updateWindowTitle();
			arrowTimer = new FlxTimer().start(0.5, (_) -> {
				currentArrowIndex = (currentArrowIndex + 1) % ARROW_ICONS.length;
				updateWindowTitle();
			}, 0);

			super.create();

			CustomShapeTransition.shape = HEAD;
			FlxG.sound.playMusic(Assets.getSound('assets/exe/music/freeplay.ogg'));
			Paths.clearUnusedMemory();

			#if DISCORD_ALLOWED
			DiscordClient.changePresence("In the Freeplay", null);
			#end

			bgSonic.color = 0xFFFF0000;
			verticalLine.color = 0xFFFF0000;
			bgChecker.color = 0xFFFF0000;

			setupBgWarp();

			return;
		}

		if (songEntries.length > 0)
		{
			Mods.currentModDirectory = songEntries[0].folder;
			PlayState.storyWeek = songEntries[0].week;
			Difficulty.loadFromWeek();
		}

		final firstSongColor = songEntries[selectedBox].songs[0].bgColor;
		bgSonic.color = FlxColor.fromRGB(firstSongColor[0], firstSongColor[1], firstSongColor[2]);
		intendedColor = bgSonic.color;
		if (verticalLine != null) verticalLine.color = intendedColor;

		curDifficulty = getNormalDiffIdx();
		if (Difficulty.list.length == 0) curDifficulty = 0;
		lastDifficultyName = Difficulty.list.length > 0 ? Difficulty.getString(curDifficulty, false) : '';

		updateSelection(false);
		loadCharText(selectedBox);
		loadSongList(selectedBox);
		changeDiff(0);
		lerpScore = intendedScore;
		lerpRating = intendedRating;
		updateScoreDisplay();

		backend.BurningBot.applyLockIfNeeded(this);

		updateWindowTitle();
		
		arrowTimer = new FlxTimer().start(0.5, (_) -> {
			currentArrowIndex = (currentArrowIndex + 1) % ARROW_ICONS.length;
			updateWindowTitle();
		}, 0);

		super.create();

		CustomShapeTransition.shape = HEAD;
		FlxG.sound.playMusic(Assets.getSound('assets/exe/music/freeplay.ogg'));
		Conductor.bpm = 96;
		Paths.clearUnusedMemory();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Freeplay", null);
		#end

		setupBgWarp();

		#if mobile createBackButton(FlxG.width - 245, FlxG.height - 710); #end
	}

	function buildSongList():Void
	{
		songEntries = [];

		var save:FlxSave = new FlxSave();
		backend.CoolUtil.bindSave(save, 'savedSongs', CoolUtil.getSavePath());
		var unlocked:Array<String> = save.data.songs;
		if (unlocked == null) unlocked = [];
		final opened:Array<String> = backend.SongProgress.openedSongs();

		for (i in 0...WeekData.weeksList.length)
		{
			if (i == 0) continue;
			
			final weekName:String = WeekData.weeksList[i];
			if (weekIsLocked(weekName)) continue;

			final leWeek:WeekData = WeekData.weeksLoaded.get(weekName);
			WeekData.setDirectoryFromWeek(leWeek);

			final songInfoList:Array<ExeSongInfo> = [];
			final weekExeTitle:String = Language.get('freeplay.title.${leWeek.exeTitle.toLowerCase().replace(" ", "")}', leWeek.exeTitle);
			final weekExeCover:String = leWeek.exeCover ?? 'placeholder';
			final weekExeLabel:String = leWeek.exeLabel ?? 'NON EXE';
			final weekTransition:String = leWeek.transitionShape ?? 'HEAD';

			for (song in leWeek.songs)
			{
				final sName:String = song[0];
				final title:String = weekExeTitle.startsWith("freeplay.title.") ? sName.toUpperCase() : weekExeTitle;

				final songPath:String = Paths.formatToSongPath(sName);
				if (songPath == 'stardust-speedway' && Mods.currentModDirectory == 'STARVED') continue;

				final burningOpen:Bool = backend.BurningBot.active || FlxG.save.data.burningRevealed == true || FlxG.save.data.burningWon == true;
				if (burningOpen && songPath == 'burning') backend.SongProgress.markOpened(songPath);
				if (unlocked.indexOf(songPath) == -1 && !opened.contains(songPath) && !(burningOpen && songPath == 'burning') #if !final && !inDevMode #end) continue;

				final info:ExeSongInfo = {
					songName: sName,
					coverFile: weekExeCover,
					title: title,
					exeLabel: weekExeLabel,
					bgColor: leWeek.bgColor,
					transitionShape: weekTransition
				};

				final minigame:String = switch ([songPath, Mods.currentModDirectory])
				{
					case ['black-sun', 'EXE']: 'The Valley';
					case ['prey', 'STARVED']: 'Stardust Speedway';
					default: null;
				}
				if (minigame != null)
					info.alt = {
						songName: minigame,
						coverFile: weekExeCover,
						title: title,
						exeLabel: weekExeLabel,
						bgColor: leWeek.bgColor,
						transitionShape: weekTransition,
						minigame: true,
						alt: info
					};

				songInfoList.push(info);
			}

			if (songInfoList.length == 0) continue;
			
			songEntries.push({
				week: i,
				folder: Mods.currentModDirectory ?? '',
				songs: songInfoList
			});
		}
	}
	
	function maniaNotif():Void 
	{
		final maniaNotifSprite = new FlxSprite();
		maniaNotifSprite.loadGraphic(Paths.getBitmapData('assets/exe/access/mania/mania-notif.webp'));
		maniaNotifSprite.scale.set(0.3, 0.3);
		maniaNotifSprite.setPosition(250, -340);
		add(maniaNotifSprite);

		FlxG.sound.play(Paths.sound('maniacorreo'));
		FlxTween.tween(maniaNotifSprite, {y: maniaNotifSprite.y + 120}, 1, {
			ease: FlxEase.circOut, 
			onComplete: (_) -> {
				new FlxTimer().start(2, (_) -> FlxTween.tween(maniaNotifSprite, {y: maniaNotifSprite.y - 140}, 1, {
					ease: FlxEase.circIn, 
					onComplete: (_) -> {
						FlxG.camera.fade(FlxColor.BLACK, 1);
						FlxG.sound.music?.fadeOut(0, 1);
						new FlxTimer().start(1, (_) -> { 
							FlxG.switchState(() -> new EXEMenu()); 
						});
					}
				}));
			}
		});
	}

	static final COVER_CACHE_MAX:Int = 8;
	var coverCache:Map<String, FlxGraphic> = [];
	var coverCacheOrder:Array<String> = [];

	function getCoverGraphic(path:String):FlxGraphic
	{
		var gfx = coverCache.get(path);
		if (gfx != null && gfx.bitmap != null)
		{
			coverCacheOrder.remove(path);
			coverCacheOrder.push(path);
			return gfx;
		}

		final bmp = loadRawBitmap(path);
		if (bmp == null) return null;

		gfx = FlxGraphic.fromBitmapData(bmp);
		gfx.persist = true;
		coverCache.set(path, gfx);
		coverCacheOrder.remove(path);
		coverCacheOrder.push(path);

		while (coverCacheOrder.length > COVER_CACHE_MAX)
		{
			final oldPath = coverCacheOrder.shift();
			final old = coverCache.get(oldPath);
			coverCache.remove(oldPath);
			if (old == null) continue;
			old.persist = false;
			if (old.useCount <= 0) old.destroy();
		}

		return gfx;
	}

	static function loadRawBitmap(path:String):BitmapData
	{
		try
		{
			#if (sys && !mobile)
			return Paths.uploadBitmap(BitmapData.fromFile(path));
			#else
			return Paths.getBitmapData(path, true, true);
			#end
		}
		catch (e:Dynamic) {}
		return null;
	}

	function createBoxesAndCovers():Void
	{
		final boxBitmap = loadRawBitmap('assets/exe/freeplayassets/FreeBox.webp');
		boxWidth = (boxBitmap != null) ? (boxBitmap.width * 0.52) - 75 : 150;

		centerX = FlxG.width / 2;
		centerY = FlxG.height / 2;

		final screenstaticFrames = FlxAtlasFrames.fromSparrow(Paths.getBitmapData('assets/exe/story/screenstatic.webp', true, true), 'assets/exe/story/screenstatic.xml');
		final placeholderBitmap = loadRawBitmap('assets/exe/freeplayassets/covers/placeholder.webp');
		final entryLangFont = Paths.font(Language.getFontForLanguage());
		final entryExeSize = Language.cjkSize(34);
		final translatedLabels = Language.getArray('freeplay.labels', []);

		for (i in 0...songEntries.length)
		{
			final entry = songEntries[i];
			final firstSong = entry.songs[0];

			final cardGroup = new FlxTypedGroup<FlxSprite>();
			cardGroups.push(cardGroup);
			cardGroupsLayer.add(cardGroup);

			final proxy = new FlxObject(0, 0);
			cardPositions.push(proxy);

			final coverPath = 'assets/exe/freeplayassets/covers/' + Paths.formatToSongPath(firstSong.songName) + '.webp';
			final coverBitmap = loadRawBitmap(coverPath) ?? placeholderBitmap;

			if (coverBitmap != null)
			{
				final cover = new FlxSprite(0, 0).loadGraphic(coverBitmap);
				cover.scale.set(0.35, 0.35);
				cover.updateHitbox();
				cover.ID = i;
				covers.add(cover);
				cardGroup.add(cover);

				final ss = new FlxSprite(0, 0);
				ss.frames = screenstaticFrames;
				ss.animation.addByPrefix('play', 'screenSTATIC', 24);
				ss.animation.play('play');
				ss.setGraphicSize(Std.int(cover.width), Std.int(cover.height));
				ss.updateHitbox();
				ss.x = cover.x;
				ss.y = cover.y;
				ss.alpha = 0.18;
				ss.ID = i;
				staticScreens.add(ss);
				cardGroup.add(ss);
			}

			if (boxBitmap != null)
			{
				final box = new FlxSprite(0, 0).loadGraphic(boxBitmap);
				box.scale.set(0.52, 0.52);
				box.updateHitbox();
				box.ID = i;

				freeBoxes.add(box);
				cardGroup.add(box);
			}

			final daColor:Int = switch (firstSong.exeLabel)
			{
				case 'NON EXE': 0xFF8888FF;
				case 'OFFICIAL': 0xFFFFDD2F;
				case 'ENTITY': 0xFFC23EFF;
				case 'GLITCH': 0xFFFFFFFF;
				case 'MEME': 0xFF19EAA8;
				default: 0xFFFF0000;
			}

			final labelIndex:Int = switch (firstSong.exeLabel)
			{
				case 'NON EXE': 1;
				case 'OFFICIAL': 2;
				case 'MEME': 3;
				case 'ENTITY': 4;
				case 'GLITCH': 5;
				default: 0;
			};

			final actualLabel = (translatedLabels.length > labelIndex) ? translatedLabels[labelIndex] : firstSong.exeLabel;

			if (songEntries.length > 0)
			{
				final exeText = new FlxText(30, 0, 0, actualLabel, entryExeSize);
				exeText.setFormat(entryLangFont, entryExeSize, daColor, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				exeText.borderSize = 2;
				exeText.ID = i;
				exeText.visible = (i == selectedBox);
				exeText.alpha = exeText.visible ? 1.0 : 0.0;
				exeText.antialiasing = false;
				exeText.updateHitbox();
				exeTexts.add(exeText);
			}
		}
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (subState != null) return;

		#if !final
		if (#if mobile shortPress && !inDevMode || #end FlxG.keys.justPressed.TAB && !inDevMode) { inDevMode = true; FlxG.resetState(); }
		#end

		#if mobile if (COOLDOWN_TIMER > 0) COOLDOWN_TIMER -= elapsed; #end

		if (songEntries.length < 1)
		{
			if ((controls.BACK #if mobile || backPressed #end) && !maniaUnlock)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxG.switchState(() -> new EXEMenu());
				FlxG.sound.music?.fadeOut(0.3);
				return;
			}

			return;
		}

		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		updateAltArrow();

		if (bgChecker != null && bgSonic != null)
		{
			bgChecker.color = bgSonic.color;
			if (!backend.BurningBot.sceneCleared) bgChecker.alpha = 0.10;
		}

		if (changeCooldown > 0) changeCooldown -= elapsed;

		final prevScore = lerpScore;
		final prevRating = lerpRating;
		
		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));
		
		if (Math.abs(lerpScore - intendedScore) <= 10) lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01) lerpRating = intendedRating;
		
		if (lerpScore != prevScore || lerpRating != prevRating) updateScoreDisplay();

		backend.BurningBot.enforceSceneCleared(this);

		if (backend.BurningBot.active)
		{
			backend.BurningBot.updateFreeplay(this, elapsed);
			return;
		}

		if ((controls.BACK #if mobile || backPressed #end) && !maniaUnlock && !backend.BurningBot.burningLocked)
		{
			if (choosingSong)
			{
				exitSongChoose();
				return;
			}
			FlxG.sound.play(Paths.sound('cancelMenu'));
			FlxG.switchState(() -> new EXEMenu());
			FlxG.sound.music?.fadeOut(0.3);
			return;
		}

		if (changeCooldown <= 0 && !choosingSong && !maniaUnlock && !backend.BurningBot.burningLocked)
		{
			var newSel = selectedBox;
			if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
			{
				newSel = selectedBox + (controls.UI_RIGHT_P ? 1 : -1);
				holdCheck = 0;
			}

			#if mobile
			if(pressHolding && deltaMouseX != 0 && COOLDOWN_TIMER <= 0) {
				if(deltaMouseX > 5) {
					newSel = selectedBox - 1;
					holdCheck = 0;
				} else if(deltaMouseX < -5) {
					newSel = selectedBox + 1;
					holdCheck = 0;
				}
			}
			#end

			if (controls.UI_LEFT || controls.UI_RIGHT) holdCheck += elapsed;
			else holdCheck = 0;
			
			newSel = FlxMath.wrap(newSel, 0, songEntries.length - 1);

			if (newSel != selectedBox)
				changeSelection(newSel);
		}

		if (choosingSong && !maniaUnlock)
		{
			if (controls.UI_DOWN_P) { chooseSong(1); holdCheck = 0; }
			if (controls.UI_UP_P) { chooseSong(-1); holdCheck = 0; }
			if (controls.UI_RIGHT_P) toggleMinigame(true);
			if (controls.UI_LEFT_P) toggleMinigame(false);

			#if mobile
			if(pressHolding && deltaMouseY != 0 && COOLDOWN_TIMER <= 0) {
				if(deltaMouseY > 5) {
					chooseSong(1);
					holdCheck = 0;
				} else if(deltaMouseY < -5) {
					chooseSong(-1);
					holdCheck = 0;
				}
			}
			if(pressHolding && Math.abs(deltaMouseX) > 5 && Math.abs(deltaMouseX) > Math.abs(deltaMouseY) && COOLDOWN_TIMER <= 0)
				toggleMinigame(deltaMouseX < 0);
			#end

			if (controls.ACCEPT #if mobile || (shortPress && FlxG.mouse.overlaps(songTexts.members[songSelector])) #end)
				launchSong();

			if (controls.RESET)
			{
				final songs2 = getSongsForBox(selectedBox);
				if (songSelector < songs2.length)
				{
					final songKey = songs2[songSelector];
					openSubState(new states.substates.ResetScoreSubState(songKey, curDifficulty, songKey));
				}
			}

			return;
		}

		if ((controls.ACCEPT #if mobile || shortPress #end) && !maniaUnlock)
			enterSelectedBox();
	}

	function enterSelectedBox():Void
	{
		holdCheck = 0;
		final entry = songEntries[selectedBox];

		Mods.currentModDirectory = entry.folder;
		PlayState.storyWeek = entry.week;
		Difficulty.loadFromWeek();

		curDifficulty = getNormalDiffIdx();
		choosingSong = true;
		cancelAllTweens();

		freeBoxes.forEach((box:FlxSprite) -> {
			if (box.ID != selectedBox)
			{
				final offset:Float = -selectedBox * boxWidth;
				final baseX = centerX + (box.ID * boxWidth) + offset;
				box.scale.set(0.52, 0.52);
				box.updateHitbox();
				box.x = baseX - box.width / 2;
				box.y = centerY - box.height / 2;
				box.alpha = 0.5;
				if (cardPositions != null && box.ID < cardPositions.length)
					cardPositions[box.ID].setPosition(box.x, box.y);
			}
		});

		covers.forEach((cover:FlxSprite) -> {
			if (cover.ID != selectedBox)
			{
				final offset:Float = -selectedBox * boxWidth;
				final baseX = centerX + (cover.ID * boxWidth) + offset;
				cover.scale.set(0.35, 0.35);
				cover.updateHitbox();
				cover.x = baseX - cover.width / 2;
				cover.y = centerY - cover.height / 2;
				cover.alpha = 0.5;
				_applyCardPosition(cover.ID);
			}
		});

		scaleSongBox(true);
		chooseSong(0, false);
	}

	function positionCover(cover:FlxSprite, ss:FlxSprite, daStatic:Bool):Void
	{
		cover.updateHitbox();
		cover.x = centerX - cover.width / 2;
		cover.y = centerY - cover.height / 2;

		if (ss != null)
		{
			ss.setGraphicSize(Std.int(cover.width), Std.int(cover.height));
			ss.updateHitbox();
			ss.x = cover.x;
			ss.y = cover.y;

			if (choosingSong && daStatic)
			{
				staticTween?.cancel();
				ss.alpha = 1.0;
				staticTween = FlxTween.tween(ss, {alpha: 0.18}, 0.45, {ease: FlxEase.quadOut});
			}
		}
	}

	function loadSongList(index:Int):Void
	{
		songSelector = 0;
		songScrollOffset = 0;

		final songs:Array<String> = getSongsForBox(index);
		activeSongCount = songs.length;

		for (spr in songTexts.members)
			if (spr != null) FlxTween.cancelTweensOf(spr);
			
		while (songTexts.length < songs.length)
		{
			final t = new FlxText(0, 0, FlxG.width, "", 48);
			t.setFormat('assets/fonts/SonicFont.ttf', 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.antialiasing = false;
			t.borderSize = 2;
			songTexts.add(t);
		}

		final slot0Y:Float = FlxG.height - 18 - (2 * 65);
		
		for (i in 0...songs.length)
		{
			final spr = songTexts.members[i];
			spr.text = (backend.BurningBot.active && songs[i] == 'burning') ? '????' : songs[i].toUpperCase();
			spr.color = FlxColor.WHITE;
			spr.ID = i;
			spr.y = slot0Y + (i * 65);
			
			if (i < 2)
			{
				spr.visible = true;
				spr.alpha = 0;
				spr.y = slot0Y + (i * 65) + 14;
				FlxTween.tween(spr, {alpha: 1.0, y: slot0Y + (i * 65)}, 0.2, {ease: FlxEase.sineOut, startDelay: i * 0.05});
			}
			else
			{
				spr.visible = false;
				spr.alpha = 0;
			}
		}

		for (i in songs.length...songTexts.length)
		{
			final extra = songTexts.members[i];
			if (extra != null) 
			{ 
				extra.visible = false;
				extra.alpha = 0; 
			}
		}
	}

	function getSongsForBox(index:Int):Array<String>
	{
		if (index < 0 || index >= songEntries.length) return [];
		return songEntries[index].songs.map(s -> s.songName);
	}

	function updateSelectedCover(daStatic:Bool = true):Void
	{
		if (selectedBox < 0 || selectedBox >= songEntries.length) return;

		final entry = songEntries[selectedBox];
		if (songSelector < 0 || songSelector >= entry.songs.length) return;

		final info = entry.songs[songSelector];
		final songName = info.minigame == true ? info.alt.songName : info.songName;
		final cover = covers.members[selectedBox];
		final ss = staticScreens.members[selectedBox];
		if (cover == null) return;

		if (songName == 'burning' && backend.BurningBot.active)
		{
			backend.BurningBot.setCoverBlackFrame(cover);
			positionCover(cover, ss, daStatic);
			return;
		}

		final coverPath = (songName == 'burning')
			? 'assets/exe/freeplayassets/covers/burning/burningidle.webp'
			: 'assets/exe/freeplayassets/covers/' + Paths.formatToSongPath(songName) + '.webp';

		var gfx = getCoverGraphic(coverPath);
		gfx ??= getCoverGraphic('assets/exe/freeplayassets/covers/placeholder.webp');

		if (gfx != null)
		{
			cover.loadGraphic(gfx);
			positionCover(cover, ss, daStatic);
		}
	}

	function chooseSong(delta:Int, daStatic:Bool = true):Void
	{
		#if mobile COOLDOWN_TIMER = 0.15; #end

		final songs = getSongsForBox(selectedBox);
		if (songs.length == 0) return;

		final newSel = songSelector + delta;
		if (newSel < 0 || newSel >= songs.length) return;
		
		songSelector = newSel;
		
		if (daStatic) 
		{
			final staticSound = FlxG.sound.play(Paths.sound('static'), 0.15);
			staticSound?.fadeOut(0.3, 0);
		}

		if (songSelector < songScrollOffset)
			songScrollOffset = songSelector;
		else if (songSelector >= songScrollOffset + 2)
			songScrollOffset = songSelector - 2 + 1;

		final slot0Y:Float = FlxG.height - 18 - (2 * 65);

		for (j in 0...activeSongCount)
		{
			final spr = songTexts.members[j];
			if (spr == null) continue;
			
			FlxTween.cancelTweensOf(spr);

			final inWindow = (spr.ID >= songScrollOffset && spr.ID < songScrollOffset + 2);
			final slot = spr.ID - songScrollOffset;
			final targetY = slot0Y + (slot * 65);
			final isSelected = (spr.ID == songSelector);

			spr.color = isSelected ? FlxColor.YELLOW : FlxColor.WHITE;

			if (inWindow)
			{
				final wasOut = !spr.visible || spr.alpha < 0.1;
				spr.visible = true;

				if (wasOut)
				{
					spr.y = targetY + (delta > 0 ? 18 : -18);
					spr.alpha = 0;
				}
				FlxTween.tween(spr, {alpha: 1.0, y: targetY}, 0.18, {ease: FlxEase.sineOut});
			}
			else
			{
				FlxTween.tween(spr, {alpha: 0.0, y: spr.y + (delta > 0 ? -4 : 4)}, 0.12, {
					ease: FlxEase.sineIn,
					onComplete: (_) -> spr.visible = false
				});
			}
		}

		if (songSelector < songs.length)
		{
			final entry = songEntries[selectedBox];
			Mods.currentModDirectory = entry.folder;
			intendedScore = Highscore.getScore(songs[songSelector], curDifficulty);
			intendedRating = Highscore.getRating(songs[songSelector], curDifficulty);
		}

		updateSelectedCover(daStatic);
	}

	function toggleMinigame(toGame:Bool):Void
	{
		final songs = songEntries[selectedBox].songs;
		final spr = songTexts.members[songSelector];
		if (songSelector >= songs.length || spr == null) return;
		final cur = songs[songSelector];
		if (cur.alt == null || (cur.minigame == true) == toGame) return;

		songs[songSelector] = cur.alt;
		spr.text = cur.alt.songName.toUpperCase();
		chooseSong(0);
		FlxTween.cancelTweensOf(spr.offset);
		spr.offset.x = toGame ? -60 : 60;
		FlxTween.tween(spr.offset, {x: 0}, 0.2, {ease: FlxEase.sineOut});
	}

	function makeAltArrow():FlxSprite
	{
		final arrow = new FlxSprite().loadGraphic(loadRawBitmap('assets/exe/freeplayassets/arrow.webp'));
		arrow.antialiasing = false;
		arrow.scale.set(2, 2);
		arrow.updateHitbox();
		arrow.visible = false;
		return arrow;
	}

	function updateAltArrow():Void
	{
		final songs = songEntries[selectedBox].songs;
		final spr = songTexts.members[songSelector];
		altArrow.visible = choosingSong && songSelector < songs.length && songs[songSelector].alt != null && spr != null && spr.visible;
		if (!altArrow.visible) return;

		final back = songs[songSelector].minigame == true;
		final reach = spr.textField.textWidth * 0.5 + 24 + Math.abs(Math.sin(FlxG.game.ticks / 1000 * 5)) * 10;
		altArrow.flipX = back;
		altArrow.x = (back ? centerX - reach - altArrow.width : centerX + reach) - spr.offset.x;
		altArrow.y = spr.y + (spr.height - altArrow.height) * 0.5;
		altArrow.alpha = spr.alpha;
		altArrow.color = spr.color;
	}

	function exitSongChoose():Void
	{
		final oldSelector:Int = songSelector;

		if (oldSelector != 0)
		{
			final staticSound = FlxG.sound.play(Paths.sound('static'), 0.15);
			staticSound?.fadeOut(0.3, 0);
		}

		final entrySongs = songEntries[selectedBox].songs;
		for (j in 0...activeSongCount)
		{
			final spr = songTexts.members[j];
			if (spr == null) continue;
			spr.color = FlxColor.WHITE;
			spr.alpha = 1;
			if (j < entrySongs.length && entrySongs[j].minigame == true)
			{
				entrySongs[j] = entrySongs[j].alt;
				spr.text = entrySongs[j].songName.toUpperCase();
			}
		}

		songSelector = 0;
		updateSelectedCover(oldSelector != 0); // reuses the burning cover
		choosingSong = false;

		scaleSongBox(false);
	}

	function launchSong():Void
	{
		final songs = getSongsForBox(selectedBox);
		if (songs.length == 0 || songSelector >= songs.length) return;
		
		final entry = songEntries[selectedBox];
		final songLower = Paths.formatToSongPath(songs[songSelector]);

		if (songLower == 'stardust-speedway' && entry.folder == 'STARVED')
		{
			FlxG.sound.play(Paths.sound('confirmMenu'));
			FlxG.sound.music?.fadeOut(0.3);
			stopMusicPlay = true;
			minigames.preymini.PreyMini.fromSoundTest = false;
			FlxG.switchState(() -> new minigames.preymini.PreyMini());
			return;
		}

		if (songLower == 'the-valley' && entry.folder == 'EXE')
		{
			FlxG.sound.play(Paths.sound('confirmMenu'));
			FlxG.sound.music?.fadeOut(0.3);
			stopMusicPlay = true;
			minigames.thevalley.TheValley.fromFreeplay = true;
			minigames.thevalley.TheValley.deaths = 0;
			FlxG.switchState(() -> new minigames.thevalley.TheValley());
			return;
		}

		minigames.preymini.PreyMini.songLives = 0;
		minigames.preymini.PreyMini.songRings = -1;
		Mods.currentModDirectory = entry.folder;
		PlayState.storyWeek = entry.week;
		Difficulty.loadFromWeek();
		final launchDiff = getNormalDiffIdx();

		final poop:String = Highscore.formatSong(songLower, launchDiff);
		
		try
		{
			Mods.currentModDirectory = entry.folder;
			Song.loadFromJson(poop, songLower);
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = launchDiff;
			PlayState.storyWeek = entry.week;
			StoryModeState.fromStoryMode = false;
			SoundTest.fromSoundTest = false;
			states.parallax.StoryParallaxState.fromParallax = false;
			states.access.FridgeAccess.fromFridge = false;
			states.access.MajinAccess.fromMajin = false;
			EXEMenu.secretSong = false;
		}
		catch (e:haxe.Exception)
		{
			var errorStr = e.message;
			if (errorStr.contains('There is no TEXT asset with an ID of'))
				errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLower), errorStr.length - 1);
			else 
				errorStr += '\n\n' + e.stack;

			missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
			missingText.screenCenter(Y);
			missingText.visible = true;
			missingTextBG.visible = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		@:privateAccess
		if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			Paths.freeGraphicsFromMemory();

		function finishLaunch():Void
		{
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			FlxG.sound.music?.fadeOut(0.3);
			stopMusicPlay = true;

			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}

		if (songLower == 'burning')
			backend.BurningBot.startBurningLaunch(this, finishLaunch);
		else
		{
			final selectedInfo = songEntries[selectedBox].songs[songSelector];
			if (selectedInfo.transitionShape != null)
				CustomShapeTransition.shape = CustomShapeTransition.getShapeByString(selectedInfo.transitionShape);

			finishLaunch();
		}
	}

	function changeSelection(newIndex:Int):Void
	{
		#if mobile COOLDOWN_TIMER = 0.15; #end
		songSelector = 0;
		updateSelectedCover();

		selectedBox = newIndex;
		changeCooldown = 0;

		final newColorArray = songEntries[selectedBox].songs[0].bgColor;
		final newColor:Int = FlxColor.fromRGB(newColorArray[0], newColorArray[1], newColorArray[2]);
		
		if (newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bgSonic);
			FlxTween.color(bgSonic, 1, bgSonic.color, intendedColor);
			if (verticalLine != null)
			{
				FlxTween.cancelTweensOf(verticalLine);
				FlxTween.color(verticalLine, 1, verticalLine.color, intendedColor);
			}
		}

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		cancelAllTweens();
		loadCharText(selectedBox);
		loadSongList(selectedBox);
		updateSelection(true);

		final songs = getSongsForBox(selectedBox);
		if (songs.length > 0)
		{
			final entry = songEntries[selectedBox];
			Mods.currentModDirectory = entry.folder;
			PlayState.storyWeek = entry.week;
			Difficulty.loadFromWeek();
			curDifficulty = getNormalDiffIdx();
			changeDiff(0);
		}
	}

	function changeDiff(delta:Int = 0):Void
	{
		if (Difficulty.list.length == 0) return;
		
		curDifficulty = FlxMath.wrap(curDifficulty + delta, 0, Difficulty.list.length - 1);
		lastDifficultyName = Difficulty.getString(curDifficulty, false);

		final songs = getSongsForBox(selectedBox);
		if (songs.length > 0)
		{
			final sel = choosingSong ? songSelector : 0;
			if (sel < songs.length)
			{
				intendedScore = Highscore.getScore(songs[sel], curDifficulty);
				intendedRating = Highscore.getRating(songs[sel], curDifficulty);
			}
		}
		positionHighscore();
	}

	function loadCharText(index:Int):Void
	{
		var title = (index >= 0 && index < songEntries.length && songEntries[index].songs.length > 0)
			? songEntries[index].songs[0].title : "???";

		if (backend.BurningBot.active && index == backend.BurningBot.targetBox)
			title = "???";

		charText.text = title;
		FlxTween.cancelTweensOf(charText);
		charText.alpha = 0;
		charText.y = 5;
		FlxTween.tween(charText, {y: 18, alpha: 1}, 0.4, {ease: FlxEase.circOut});
	}

	static function getRankLetter(rating:Float):String
	{
		if (rating >= 1) return 'P';
		if (rating >= 0.96) return 'SS';
		if (rating >= 0.93) return 'S';
		if (rating >= 0.85) return 'AA';
		if (rating >= 0.75) return 'A';
		if (rating >= 0.6) return 'B';
		if (rating >= 0.45) return 'C';
		if (rating >= 0.2) return 'D';
		if (rating > 0.0) return 'F';
		return '?';
	}

	function updateScoreDisplay():Void
	{
		if (scoreText == null) return;
		scoreText.text = Language.get('freeplay.score', 'SCORE') + ': ${lerpScore}';
		if (rankText != null)
			rankText.text = Language.get('freeplay.rank', 'RANK') + ': ' + getRankLetter(lerpRating);
			
		positionHighscore();
	}

	function positionHighscore():Void
	{
		if (scoreText == null || rankText == null) return;

		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreText.y = rankText.y - scoreText.height - 15;
		rankText.x = FlxG.width - rankText.width - 6;
		rankText.y = FlxG.height - rankText.height - 25;
	}

	function scaleSongBox(enlarge:Bool):Void
	{
		final targetBoxScale = enlarge ? 0.63 : 0.58;
		final targetCoverScale = enlarge ? 0.421 : 0.39;
		
		freeBoxes.forEach((box:FlxSprite) -> {
			FlxTween.cancelTweensOf(box); 
			FlxTween.cancelTweensOf(box.scale);
			
			if (box.ID == selectedBox)
			{
				final idx = box.ID;
				FlxTween.tween(box.scale, {x: targetBoxScale, y: targetBoxScale}, 0.42, {
					ease: FlxEase.backOut,
					onUpdate: (_) -> {
						box.updateHitbox();
						box.x = centerX - box.width / 2;
						box.y = centerY - box.height / 2;
						if (cardPositions != null && idx < cardPositions.length)
							cardPositions[idx].setPosition(box.x, box.y);
					}
				});
				FlxTween.tween(box, {alpha: 1.0}, 0.42, {ease: FlxEase.cubeOut});
			}
			else
			{
				FlxTween.tween(box, {alpha: 0.5}, 0.42, {ease: FlxEase.cubeOut});
			}
		});

		covers.forEach((cover:FlxSprite) -> {
			FlxTween.cancelTweensOf(cover); 
			FlxTween.cancelTweensOf(cover.scale);
			
			if (cover.ID == selectedBox)
			{
				final ss = staticScreens.members[cover.ID];
				FlxTween.tween(cover.scale, {x: targetCoverScale, y: targetCoverScale}, 0.42, {
					ease: FlxEase.backOut,
					onUpdate: (_) -> {
						cover.updateHitbox();
						cover.x = centerX - cover.width / 2;
						cover.y = centerY - cover.height / 2;
						if (ss != null)
						{
							ss.setGraphicSize(Std.int(cover.width), Std.int(cover.height));
							ss.updateHitbox();
							ss.x = cover.x;
							ss.y = cover.y;
						}
					}
				});
				FlxTween.tween(cover, {alpha: 1.0}, 0.42, {ease: FlxEase.cubeOut});
			}
			else
			{
				FlxTween.tween(cover, {alpha: 0.5}, 0.42, {ease: FlxEase.cubeOut});
			}
		});
	}

	function updateSelection(animate:Bool = true):Void
	{
		final offset:Float = -selectedBox * boxWidth;

		for (i in 0...songEntries.length)
		{
			final isSelected = (i == selectedBox);
			final proxy = cardPositions[i];
			final box = freeBoxes.members[i];
			final cover = covers.members[i];
			final ss = staticScreens.members[i];

			final targetAlpha:Float = isSelected ? 1.0 : 0.5;
			final targetBoxScale = isSelected ? 0.58 : 0.52;
			final targetCoverScale = isSelected ? 0.39 : 0.35;
			final baseX = centerX + (i * boxWidth) + offset;

			final finalBoxW = (box != null) ? box.frameWidth * targetBoxScale : 0;
			final finalBoxH = (box != null) ? box.frameHeight * targetBoxScale : 0;
			final targetX = baseX - finalBoxW / 2;
			final targetY = centerY - finalBoxH / 2;

			if (animate)
			{
				final fi = i;

				if (box != null)
				{
					FlxTween.cancelTweensOf(box.scale);
					FlxTween.tween(box.scale, {x: targetBoxScale, y: targetBoxScale}, 0.42, {
						ease: FlxEase.expoOut,
						onUpdate: (_) -> box.updateHitbox()
					});
				}
				if (cover != null)
				{
					FlxTween.cancelTweensOf(cover.scale);
					FlxTween.tween(cover.scale, {x: targetCoverScale, y: targetCoverScale}, 0.42, {
						ease: FlxEase.expoOut,
						onUpdate: (_) -> cover.updateHitbox()
					});
				}

				FlxTween.cancelTweensOf(proxy);
				FlxTween.tween(proxy, {x: targetX, y: targetY}, 0.42, {
					ease: FlxEase.expoOut,
					onUpdate: (_) -> _applyCardPosition(fi)
				});

				if (box != null) FlxTween.tween(box, {alpha: targetAlpha}, 0.42, {ease: FlxEase.expoOut});
				if (cover != null) FlxTween.tween(cover, {alpha: targetAlpha}, 0.42, {ease: FlxEase.expoOut});
			}
			else
			{
				if (box != null) { box.scale.set(targetBoxScale, targetBoxScale); box.updateHitbox(); }
				if (cover != null) { cover.scale.set(targetCoverScale, targetCoverScale); cover.updateHitbox(); }
				proxy.setPosition(targetX, targetY);
				_applyCardPosition(i);
				if (box != null) box.alpha = targetAlpha;
				if (cover != null) cover.alpha = targetAlpha;
			}
		}

		exeTexts.forEach((text:FlxText) -> {
			FlxTween.cancelTweensOf(text);
			text.y = FlxG.height - text.height - 30;
			
			if (text.ID == selectedBox)
			{
				text.visible = true;
				if (animate)
					FlxTween.tween(text, {alpha: 1.0}, 0.42, {ease: FlxEase.cubeOut});
				else
					text.alpha = 1.0;
			}
			else
			{
				text.visible = false;
				text.alpha = 0.0;
			}
		});
	}

	inline function _applyCardPosition(i:Int):Void
	{
		final proxy = cardPositions[i];
		final box = freeBoxes.members[i];
		final cover = covers.members[i];
		final ss = staticScreens.members[i];
		
		if (box != null)
		{
			box.x = proxy.x;
			box.y = proxy.y;
		}
		
		if (cover != null)
		{
			final offsetX = box != null ? (box.width - cover.width) / 2 : 0;
			final offsetY = box != null ? (box.height - cover.height) / 2 : 0;
			cover.x = proxy.x + offsetX;
			cover.y = proxy.y + offsetY;
			
			if (ss != null) 
			{ 
				ss.setGraphicSize(Std.int(cover.width), Std.int(cover.height)); 
				ss.updateHitbox(); 
				ss.x = cover.x; 
				ss.y = cover.y;
			}
		}
	}

	override function stepHit():Void
	{
		super.stepHit();
		if (curStep % 1 == 0 && holdCheck > ((Conductor.bpm / 60) / 4)) 
			changeSelection(FlxMath.wrap(selectedBox + (controls.UI_RIGHT ? 1 : -1), 0, songEntries.length - 1));
	}

	function loadBgChecker():Void
	{
		final tileSize:Int = 40;
		final bmp = new openfl.display.BitmapData(tileSize * 2, tileSize * 2, false, 0xFF000000);
		bmp.fillRect(new openfl.geom.Rectangle(0, 0, tileSize, tileSize), 0xFF888888);
		bmp.fillRect(new openfl.geom.Rectangle(tileSize, tileSize, tileSize, tileSize), 0xFF888888);
		
		bgChecker = new FlxBackdrop(bmp, FlxAxes.XY);
		bgChecker.antialiasing = false;
		bgChecker.velocity.y = 60;
		bgChecker.alpha = 0.10;
		add(bgChecker);
	}

	function loadBgSonic():Void
	{
		final bmp = loadRawBitmap('assets/exe/freeplayassets/bgsonic.webp');
		if (bmp == null) return;

		bgSonic = new FlxBackdrop(bmp, FlxAxes.X);
		bgSonic.antialiasing = false;
		bgSonic.velocity.x = 55;
		add(bgSonic);
	}

	function setupBgWarp():Void
	{
		if (!ClientPrefs.data.shaders) return;
		if (bgSonic == null && bgChecker == null) return;

		bgCam = new FlxCamera();
		bgCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.insert(bgCam, 0, false);
		FlxG.camera.bgColor = FlxColor.TRANSPARENT;

		if (bgSonic != null) bgSonic.cameras = [bgCam];
		if (bgChecker != null) bgChecker.cameras = [bgCam];
		if (verticalLine != null) verticalLine.cameras = [bgCam];
		if (cardGroupsLayer != null) cardGroupsLayer.cameras = [bgCam];
		if (degradado != null) degradado.cameras = [bgCam];
		if (spikesUp != null) spikesUp.cameras = [bgCam];

		pincushionShader = new PincushionShader();
		bgCam.filters = [new ShaderFilter(pincushionShader)];
	}

	function loadVerticalLine():Void
	{
		final lh = 20;

		verticalLine = FlxGradient.createGradientFlxSprite(1, lh, [0xFF4B4B4B, 0xFF1A1A1A], 1, 90);
		verticalLine.origin.set(0, 0);
		verticalLine.scale.x = FlxG.width * 2;
		verticalLine.setPosition(0, FlxG.height / 2 - lh / 2);

		add(verticalLine);
	}

	function loadVignette():Void
	{
		final vigWLeft:Int = 420;
		final vigWRight:Int = 420;
		final vigH:Int = 200;
		
		final left = FlxGradient.createGradientFlxSprite(vigWLeft, FlxG.height, [0x55000000, 0x00000000], 1, 0);
		left.x = -vigWLeft / 2;
		left.scrollFactor.set(0, 0);
		add(left);
		
		final right = FlxGradient.createGradientFlxSprite(vigWRight, FlxG.height, [0x00000000, 0x55000000], 1, 0);
		right.x = FlxG.width - vigWRight / 2;
		right.scrollFactor.set(0, 0);
		add(right);
		
		final top = FlxGradient.createGradientFlxSprite(FlxG.width, vigH, [0x66000000, 0x00000000], 1, 90);
		top.scrollFactor.set(0, 0);
		add(top);
	}

	function loadDegradado():Void
	{
		final h = Std.int(FlxG.height / 2);
		degradado = FlxGradient.createGradientFlxSprite(1, h, [0x00000000, 0xF2000000, 0xFF000000], 1, 90);
		degradado.origin.set(0, 0);
		degradado.scale.x = FlxG.width;
		degradado.setPosition(0, FlxG.height - h);
		degradado.scrollFactor.set(0, 0);
		add(degradado);
	}

	function loadSpikesUp():Void
	{
		final bmp = loadRawBitmap('assets/exe/freeplayassets/spikesup.webp');
		if (bmp == null) return;
		
		spikesUp = new FlxBackdrop(bmp, FlxAxes.X);
		spikesUp.scale.set(0.5, 0.5);
		spikesUp.updateHitbox();
		spikesUp.y = -25;
		spikesUp.velocity.x = -80;
		
		add(spikesUp);
	}

	function updateWindowTitle():Void
	{
		if (FlxG.stage?.window != null)
			FlxG.stage.window.title = ARROW_ICONS[currentArrowIndex] + " FREEPLAY " + ARROW_ICONS[currentArrowIndex];
	}

	inline function getNormalDiffIdx():Int
	{
		final idx = Lambda.findIndex(Difficulty.list, d -> d.toLowerCase() == 'normal');
		return idx > -1 ? idx : 0;
	}

	function weekIsLocked(name:String):Bool
	{
		final w:WeekData = WeekData.weeksLoaded.get(name);
		return !w.startUnlocked && w.weekBefore.length > 0
			&& (!StoryModeState.weekCompleted.exists(w.weekBefore) || !StoryModeState.weekCompleted.get(w.weekBefore));
	}

	function cancelAllTweens():Void
	{
		freeBoxes?.forEach((b) -> { FlxTween.cancelTweensOf(b); FlxTween.cancelTweensOf(b.scale); });
		covers?.forEach((c) -> { FlxTween.cancelTweensOf(c); FlxTween.cancelTweensOf(c.scale); });
		
		exeTexts?.forEach((t) -> {
			FlxTween.cancelTweensOf(t);
			if (t.ID == selectedBox) { 
				t.visible = true; 
				t.alpha = 1.0; 
			} else { 
				t.visible = false; 
				t.alpha = 0.0; 
			}
		});
		
		songTexts?.forEach((t) -> FlxTween.cancelTweensOf(t));
		
		if (charText != null)
		{
			FlxTween.cancelTweensOf(charText);
			charText.alpha = 1.0;
			charText.y = 18;
		}
		
		if (cardPositions != null) 
			for (p in cardPositions) FlxTween.cancelTweensOf(p);
	}

	override function closeSubState():Void
	{
		super.closeSubState();
		if (choosingSong)
		{
			final songs2 = getSongsForBox(selectedBox);
			if (songSelector < songs2.length)
			{
				intendedScore = Highscore.getScore(songs2[songSelector], curDifficulty);
				intendedRating = Highscore.getRating(songs2[songSelector], curDifficulty);
			}
		}
	}

	override function destroy():Void
	{
		if (FlxG.stage?.window != null)
			FlxG.stage.window.title = previousWindowName;
			
		arrowTimer?.cancel();
		arrowTimer = null;

		staticTween?.cancel();
		staticTween = null;

		if (bgCam != null)
		{
			bgCam.filters = [];
			if (FlxG.cameras.list.indexOf(bgCam) != -1) FlxG.cameras.remove(bgCam);
			bgCam = null;
		}
		pincushionShader = null;

		cancelAllTweens();

		for (gfx in coverCache)
		{
			gfx.persist = false;
			if (!gfx.isDestroyed) gfx.destroy();
		}
		coverCache.clear();
		coverCacheOrder = [];

		if (!stopMusicPlay)
			FlxG.sound.playMusic(Assets.getSound('assets/exe/music/menu.ogg'));

		super.destroy();
	}
}