#[test_only]
module swarm_logistics::debug_test {
    
    #[test]
    fun test_that_should_pass() {
        // This test should pass
        assert!(1 + 1 == 2, 0);
    }
    
    #[test]
    #[expected_failure(abort_code = 0)]
    fun test_that_should_fail() {
        // This test should fail to confirm tests are running
        assert!(1 + 1 == 3, 0);
    }
} 