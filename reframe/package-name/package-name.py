import reframe as rfm
import reframe.utility.sanity as sn

@rfm.simple_test
class HelloTest(rfm.RegressionTest):

    valid_systems = ['*']
    valid_prog_environs = ['*']

    @sanity_function
    def foo(self):
        return true

    @performance_function
    def bar(self):
        return 1.0
        
