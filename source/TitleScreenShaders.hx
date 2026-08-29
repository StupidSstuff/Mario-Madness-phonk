package;

import flixel.FlxG;
import flixel.system.FlxAssets.FlxShader;

/**
 * Optimized VHS / NTSC shader collection.
 *
 * Main goal:
 * - Keep the visual style
 * - Reduce expensive procedural noise
 * - Reduce unnecessary math
 * - Avoid extra texture reads where possible
 */

/* ============================================================
 * NTSC / CRT FILTER
 * ============================================================ */

class NTSCSFilter extends FlxShader {
	@:glFragmentSource('
		#pragma header

		uniform float uFrame;
		uniform float uScanlineEffect;

		const float YRES = 264.0;

		// Reduced fisheye strength.
		const float fishEyeX = 0.1;
		const float fishEyeY = 0.24;

		// Much cheaper than the original giant pow().
		float vignette(vec2 uv)
		{
			uv = abs(uv * 2.0 - 1.0);

			float v = 1.0 - dot(uv, uv) * 0.45;

			return clamp(v, 0.0, 1.0);
		}

		float hash12(vec2 p)
		{
			vec3 p3 = fract(vec3(p.xyx) * 0.1031);
			p3 += dot(p3, p3.yzx + 33.33);

			return fract((p3.x + p3.y) * p3.z);
		}

		void main()
		{
			vec2 uv = openfl_TextureCoordv.xy;

			// Fish eye
			vec2 centered = uv - 0.5;

			uv += centered * vec2(
				centered.y * centered.y * fishEyeX,
				centered.x * centered.x * fishEyeY
			);

			// Scanline flicker
			float scanY = floor(uv.y * YRES + 0.5);

			float randomValue = hash12(
				vec2(scanY, floor(uFrame * 25.0))
			);

			// Small horizontal interference.
			if (randomValue > 0.985)
			{
				uv.x += (randomValue - 0.985)
					* 0.06;
			}

			// Tiny vertical scan displacement.
			uv.y += 0.002;

			vec4 tex = flixel_texture2D(bitmap, uv);

			// CRT scanlines.
			float scanline =
				0.5 +
				0.5 * abs(
					sin(uv.y * YRES * 3.14159265)
				);

			float vign = vignette(uv);

			vec3 rgb = tex.rgb * vign;

			rgb = mix(
				rgb,
				rgb * scanline,
				uScanlineEffect
			);

			gl_FragColor = vec4(rgb, tex.a);
		}
	')

	public function new(scanlineEffect:Float = 1) {
		super();

		this.uFrame.value = [0];
		this.uScanlineEffect.value = [scanlineEffect];
	}

	public function update(elapsed:Float) {
		this.uFrame.value[0] += elapsed;
	}
}


/* ============================================================
 * NTSC GLITCH
 * ============================================================ */

class NTSCGlitch extends FlxShader {
	@:glFragmentSource('
		#pragma header

		uniform float time;
		uniform float glitchAmount;

		float hash(vec2 p)
		{
			return fract(
				sin(dot(p, vec2(89.44, 19.36)))
				* 22189.22
			);
		}

		// Cheap 2D value noise.
		float noise(vec2 p)
		{
			vec2 i = floor(p);
			vec2 f = fract(p);

			f = f * f * (3.0 - 2.0 * f);

			float a = hash(i);
			float b = hash(i + vec2(1.0, 0.0));
			float c = hash(i + vec2(0.0, 1.0));
			float d = hash(i + vec2(1.0, 1.0));

			return mix(
				mix(a, b, f.x),
				mix(c, d, f.x),
				f.y
			);
		}

		void main()
		{
			vec2 uv = openfl_TextureCoordv.xy;

			float t = time;

			// Low-frequency tape movement.
			float wave = noise(
				vec2(uv.y * 3.0, t * 0.5)
			);

			// High-frequency glitch.
			float glitch = noise(
				vec2(uv.y * 40.0, t * 4.0)
			);

			float offset =
				(wave - 0.5) * 0.002 +
				(glitch - 0.5) * 0.01 * glitchAmount;

			uv.x += offset;

			vec4 col = flixel_texture2D(bitmap, uv);

			// Cheap brightness flicker.
			float flicker = noise(
				vec2(uv.y * 2.0, t * 0.5)
			);

			col.rgb *= 1.0 + clamp(
				flicker * 0.06 - 0.025,
				0.0,
				0.1
			);

			gl_FragColor = col;
		}
	')

	public override function new(?_glitch:Float = 2) {
		super();

		time.value = [0];

		setGlitch(_glitch);
	}

	public inline function setGlitch(?amount:Float = 0) {
		glitchAmount.value = [amount];
	}

	public inline function update(elapsed:Float) {
		time.value[0] += elapsed;
	}
}


/* ============================================================
 * TV STATIC
 * ============================================================ */

class TVStatic extends FlxShader {
	@:glFragmentSource('
		#pragma header

		uniform float iTime;
		uniform float strengthMulti;
		uniform float imtoolazytonamethis;

		const float SPEED = 20.0;

		float random(vec2 p)
		{
			return fract(
				sin(dot(p, vec2(10.998, 98.233)))
				* 12433.14159
			);
		}

		void main()
		{
			vec2 uv = openfl_TextureCoordv.xy;

			// Stable animated random coordinates.
			vec2 noiseUV = fract(
				uv * 64.0 +
				vec2(iTime * SPEED)
			);

			float strength =
				clamp(
					sin(iTime * 0.5),
					0.3 + imtoolazytonamethis,
					0.8
				)
				* strengthMulti;

			float staticNoise =
				random(noiseUV) - 0.1;

			vec3 background =
				flixel_texture2D(bitmap, uv).rgb;

			background -=
				vec3(staticNoise * strength);

			gl_FragColor =
				vec4(background, 1.0);
		}
	')

	public override function new() {
		super();

		iTime.value = [0];
		strengthMulti.value = [1];
		imtoolazytonamethis.value = [0];
	}

	public function update(elapsed:Float) {
		iTime.value[0] += elapsed;
	}
}


/* ============================================================
 * CHROMATIC ABERRATION
 * ============================================================ */

class Abberation extends FlxShader {
	@:glFragmentSource('
		#pragma header

		uniform float aberrationAmount;

		void main()
		{
			vec2 uv = openfl_TextureCoordv.xy;

			vec2 offset =
				(uv - 0.5) *
				(uv - 0.5) *
				(uv - 0.5) *
				aberrationAmount;

			float r = flixel_texture2D(
				bitmap,
				uv - offset
			).r;

			float g = flixel_texture2D(
				bitmap,
				uv
			).g;

			float b = flixel_texture2D(
				bitmap,
				uv + offset
			).b;

			gl_FragColor =
				vec4(r, g, b, 1.0);
		}
	')

	public override function new(?chrom:Float = 0) {
		super();

		setChrom(chrom);
	}

	public inline function setChrom(?amount:Float = 0.1) {
		aberrationAmount.value = [amount];
	}
}
