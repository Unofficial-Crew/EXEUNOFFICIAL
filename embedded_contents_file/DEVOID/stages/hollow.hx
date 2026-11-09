import openfl.display.BlendMode;
import flixel.tweens.FlxTween.FlxTweenType;

/**
 * I HATE HSCRIPT-IRIS
 * IT'S FUCKING PIECE OF BULLSHIT BRUH
 * RULESCRIPT IS MUCH BETTER
 */
final bg:Array<BackgroundSprite> = [
	{path: 'hollow/sky', position: [-850, -300], scroll: [0.35, 0.35]},
	{path: 'hollow/cloud1', position: [-800, -300], scroll: [0.35, 0.35], backdrop: ['x', [50, 0]]},
	{path: 'hollow/cloud2', position: [-800, -300], scroll: [0.35, 0.35], backdrop: ['x', [50, 0]]},
	{path: 'hollow/FalseSonicBro', position: [1952, 50], scale: [0.7, 0.7], scroll: [0.7, 0.7], isAtlas: true, animation: [{name: 'Símbolo 1'}], alpha: 0.0001}
	{path: 'hollow/city', position: [-400, -100], scroll: [0.7, 0.7]},
	{path: 'hollow/falsebot', position: [1600, 0], scale: [0.5, 0.5], isAtlas: true, animation: [{name: 'falseappear'}, {name: 'idle', looped: true}], alpha: 0.0001}
	{path: 'hollow/floor'},
	{path: 'hollow/fg', position: [300, 300], scroll: [1.2, 1.2], front: true}
];

final _trailPoolSize:Int = 8;
var _trails:Array<Character> = [];
var _trailTweens:Array<FlxTween> = [];
var _nextTrail:Int = 0;
function spawnTrail()
{
	if (dad.animation.curAnim == null) return;

	final index:Int = _nextTrail;
	_nextTrail = (_nextTrail + 1) % _trailPoolSize;

	var trail:Character = _trails[index];
	if (_trailTweens[index] != null) _trailTweens[index].cancel();

	trail.setPosition(dad.x, dad.y);
	trail.alpha = 0.8;
	trail.holdTimer = 0;
	trail.playAnim(dad.animation.curAnim.name, true);
	trail.visible = true;
	trail.active = true;

	_trailTweens[index] = FlxTween.tween(trail, {alpha: 0}, 0.5, {ease: FlxEase.circOut, onComplete: function(_)
	{
		trail.visible = false;
		trail.active = false;
		_trailTweens[index] = null;
	}});
}

function onCreate()
{
	makeBackground(bg);

	var overlay:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF060d94);
	overlay.alpha = 0.25;
	overlay.blend = BlendMode.MULTIPLY;
	overlay.camera = camVideo;
	add(overlay);

	createBadnickPool();
}

function onCreatePost()
{
	for (i in 0..._trailPoolSize)
	{
		var trail:Character = new Character(0, 0, dad.curCharacter, dad.isPlayer);
		trail.updateHitbox();
		trail.visible = false;
		trail.active = false;
		add(trail);
		_trails.push(trail);
		_trailTweens.push(null);
	}
}

final _badnickPoolSize:Int = 8;
var _badnicks:Array<FlxSprite> = [];
var _badnickTweens:Array<FlxTween> = [];
var _badnickOffsets:Array<Array<Float>> = [];
function createBadnickPool()
{
	for (i in 0..._badnickPoolSize)
	{
		final setupBadnick:Array<BackgroundSprite> = [{path: 'hollow/badnick', position: [500, 0], scale: [0.5, 0.5], scroll: [0.7, 0.7], isAtlas: true, animation: [{name: 'visorappear'}, {name: 'idlevisor', looped: true}, {name: 'murcielgao', looped: true}, {name: 'Símbolo 23', looped: true}, {name: 'abejorro', looped: true}], layer: (PlayState.instance.members.indexOf(bg[5].sprite)), alpha: 0.0001}];
		makeBackground(setupBadnick);

		var badnick:FlxSprite = setupBadnick[0].sprite;
		badnick.visible = i == 0;
		badnick.active = false;
		_badnicks.push(badnick);
		_badnickTweens.push(null);
		_badnickOffsets.push([badnick.offset.x, badnick.offset.y]);
	}
}

function releaseOffscreenBadnicks()
{
	for (i in 0..._badnickPoolSize)
	{
		var badnick:FlxSprite = _badnicks[i];
		if (!badnick.active || (badnick.x > -700 && badnick.x < 3400)) continue;

		badnick.visible = false;
		badnick.active = false;
		badnick.velocity.set(0, 0);
		badnick.acceleration.set(0, 0);
		_badnickTweens[i]?.cancel();
		_badnickTweens[i] = null;
	}
}

var _startSpawning:Bool = false;
var _dadHardMode:Bool = false;
function onEvent(n, v1)
{
	if (n == 'BG Freaks Expression') _dadHardMode = !_dadHardMode;

	if (n == 'Dadbattle Spotlight')
	{
		if (!_startSpawning) _startSpawning = true;
		spawnBadnick();
	}
	if (n == 'Trigger BG Ghouls')
	{
		bg[5].sprite.animation.play('falseappear', true);
		bg[5].sprite.offset.set(0, 0);
		bg[5].sprite.alpha = 1;
		FlxTween.tween(bg[5].sprite, {y: bg[5].sprite.y + 20}, Conductor.crochet / 250, {type: FlxTweenType.PINGPONG, ease: FlxEase.sineInOut});
		bg[5].sprite.animation.onFinish.addOnce(function(_)
		{
			bg[5].sprite.animation.play('idle', true);
			bg[5].sprite.offset.set(-25, -199);
		});
	}
	if (n == 'Kill Henchmen')
	{
		FlxTween.tween(camHUD, {alpha: 0.15}, 1);
		bg[3].sprite.animation.play('Símbolo 1', true);
		bg[3].sprite.alpha = 1;
		bg[3].sprite.animation.onFinish.addOnce(function(_)
		{
			FlxTween.tween(camHUD, {alpha: 1}, 1);
			bg[3].sprite.alpha = 0;
		});
	}
}

function onSongStart()
{
	_badnicks[0]?.visible = false;
}

function onSectionHit()
{
	if (!_startSpawning) return;

	releaseOffscreenBadnicks();
	if (FlxG.random.bool(25)) spawnBadnick();
}

function opponentNoteHitPre(note)
{
	if (_dadHardMode && note.animSuffix == '') note.animSuffix = '-hard';
}

function opponentNoteHit(note)
{
	if (curStep >= 1568 && curStep < 1824) spawnTrail();
}

function spawnBadnick()
{
	var index:Int = -1;
	for (i in 0..._badnickPoolSize)
	{
		if (!_badnicks[i].active)
		{
			index = i;
			break;
		}
	}
	if (index == -1) return;

	final t:Int = FlxG.random.int(0,3);
	var badnick:FlxSprite = _badnicks[index];
	badnick.alpha = 1;
	badnick.visible = true;
	badnick.active = true;
	badnick.offset.set(_badnickOffsets[index][0], _badnickOffsets[index][1]);
	badnick.flipX = FlxG.random.bool();
	badnick.y = FlxG.random.int(50, 350);
	_badnickTweens[index] = FlxTween.tween(badnick, {y: badnick.y + 20}, Conductor.crochet / 250, {type: FlxTweenType.PINGPONG, ease: FlxEase.sineInOut});
	badnick.x =(t == 0 || t == 3) ? (badnick.flipX ? (t == 3 ? 100 : -100) : (t == 3 ? 1700 : 2800)) : (badnick.flipX ? 2800 : -150);
	if (t < 3)
	{
		badnick.animation.play(['abejorro', 'Símbolo 23', 'murcielgao'][t], true);
		badnick.velocity.x = FlxG.random.int(100, 200) * (badnick.flipX ? -1 : 1) * (t == 0 ? -1 : 1);
	}
	else
	{
		badnick.animation.play('visorappear', true);
		badnick.offset.set(0, 0);
		badnick.animation.onFinish.addOnce(function(_)
		{
			badnick.animation.play('idlevisor', true);
			badnick.acceleration.x = FlxG.random.int(50, 100) * (badnick.flipX ? 1 : -1);
			if (badnick.flipX) badnick.offset.set(-218, -63);
			else badnick.offset.set(-25, -63);
		});
	}
}