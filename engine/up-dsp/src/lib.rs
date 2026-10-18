//! Realtime-safe DSP primitives. Nothing in this crate allocates in its
//! `process`/`next` methods.

#![forbid(unsafe_code)]

pub mod gain;
pub mod interp;
pub mod limiter;
pub mod meter;
pub mod ramp;
pub mod stretch;

pub use gain::{db_to_linear, linear_to_db, pan_gains, velocity_to_gain};
pub use interp::hermite4;
pub use limiter::{Limiter, LimiterConfig};
pub use meter::{PeakMeter, RmsMeter, StereoMeter};
pub use ramp::{Fade, FadeState, SmoothedValue};
