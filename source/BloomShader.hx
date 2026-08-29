package;

import flixel.system.FlxAssets.FlxShader;

class BloomShader extends FlxShader
{
	@:glFragmentSource('
#pragma header

uniform float dim;
uniform float Directions;
uniform float Quality;
uniform float Size;

void main(void)
{
    vec2 uv = openfl_TextureCoordv.xy;
    vec4 original = flixel_texture2D(bitmap, uv);

    // Skip the blur entirely when effectively disabled.
    if (Size <= 0.0 || Directions <= 0.0 || Quality <= 0.0)
    {
        gl_FragColor = original;
        return;
    }

    vec4 Color = original;

    // 4 directions × 2 samples = 8 texture lookups
    float dirStep = 6.28318530718 / 4.0;

    for (int d = 0; d < 4; d++)
    {
        float angle = float(d) * dirStep;
        vec2 direction = vec2(cos(angle), sin(angle));

        Color += flixel_texture2D(
            bitmap,
            uv + direction * (Size * 0.5) / openfl_TextureSize
        );

        Color += flixel_texture2D(
            bitmap,
            uv + direction * Size / openfl_TextureSize
        );
    }

    Color /= 9.0;

    vec4 bloom = (original / dim) + Color;

    gl_FragColor = bloom;
}
	')
	public function new()
	{
		super();

		Size.value = [18.0];
		Quality.value = [8.0];
		dim.value = [2.0];
		Directions.value = [16.0];
	}
}
