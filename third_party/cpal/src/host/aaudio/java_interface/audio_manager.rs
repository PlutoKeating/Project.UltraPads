use super::{
    utils::{get_context, get_system_property, get_system_service, with_attached, Env, JResult, JString},
    AudioManager,
};

impl AudioManager {
    /// UltraPads patch: the device's native output sample rate
    /// (`AudioManager.getProperty(PROPERTY_OUTPUT_SAMPLE_RATE)`).
    pub fn get_output_sample_rate() -> Result<u32, String> {
        let context = get_context();
        with_attached(context, |env, context| get_output_sample_rate(env, &context))
            .map_err(|error| error.to_string())?
            .ok_or_else(|| "PROPERTY_OUTPUT_SAMPLE_RATE is not available".to_owned())
    }

    /// Get the AAudio mixer burst count from system property
    pub fn get_mixer_bursts() -> Result<i32, String> {
        let context = get_context();

        with_attached(context, |env, _context| get_mixer_bursts(env))
            .map_err(|error| error.to_string())
    }
}

fn get_mixer_bursts<'j>(env: &mut Env<'j>) -> JResult<i32> {
    let mixer_bursts = get_system_property(env, "aaudio.mixer_bursts", "2")?;

    let mixer_bursts_string = String::from(mixer_bursts.mutf8_chars(env)?);

    mixer_bursts_string
        .parse::<i32>()
        .map_err(|e| jni::errors::Error::ParseFailed(e.to_string()))
}

fn get_output_sample_rate<'j>(
    env: &mut Env<'j>,
    context: &jni::objects::JObject<'j>,
) -> JResult<Option<u32>> {
    let manager = get_system_service(env, context, "audio")?;
    let key = env.new_string("android.media.property.OUTPUT_SAMPLE_RATE")?;
    let value = env
        .call_method(
            &manager,
            jni::jni_str!("getProperty"),
            jni::jni_sig!("(Ljava/lang/String;)Ljava/lang/String;"),
            &[(&key).into()],
        )?
        .l()?;
    if value.is_null() {
        return Ok(None);
    }
    let value = unsafe { JString::from_raw(env, value.into_raw()) };
    let text = String::from(value.mutf8_chars(env)?);
    Ok(text.trim().parse::<u32>().ok().filter(|r| *r > 0))
}
