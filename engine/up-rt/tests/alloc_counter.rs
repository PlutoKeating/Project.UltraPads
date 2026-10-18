use up_rt::alloc_check::{CountingAlloc, count_allocs};

#[global_allocator]
static A: CountingAlloc = CountingAlloc;

#[test]
fn counts_allocations() {
    let (v, n) = count_allocs(|| vec![1u8; 32]);
    assert!(n >= 1);
    let ((), n) = count_allocs(|| drop(v));
    assert_eq!(n, 1);
    let mut x = 0u64;
    let ((), n) = count_allocs(|| {
        for i in 0..1000 {
            x = x.wrapping_add(i);
        }
    });
    assert_eq!(n, 0);
    assert!(x > 0);
}

#[test]
fn queues_do_not_allocate_in_steady_state() {
    let q = up_rt::mpsc::CommandQueue::<[u64; 4]>::new(64);
    let (mut tx, mut rx) = up_rt::spsc::channel::<u64>(64);
    let ((), n) = count_allocs(|| {
        for i in 0..32 {
            q.push([i; 4]).unwrap();
            tx.push(i).unwrap();
        }
        while q.pop().is_some() {}
        while rx.pop().is_ok() {}
    });
    assert_eq!(n, 0);
}
