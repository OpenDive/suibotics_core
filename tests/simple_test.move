#[test_only]
module swarm_logistics::simple_test {
    
    #[test]
    fun test_basic_math() {
        assert!(1 + 1 == 2, 0);
        assert!(5 * 2 == 10, 1);
    }

    #[test]
    fun test_string_operations() {
        let hello = b"Hello".to_string();
        let world = b"World".to_string();
        assert!(hello != world, 0);
    }
} 