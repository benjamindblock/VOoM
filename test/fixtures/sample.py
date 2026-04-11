class TopLevel:
    """A top-level class."""

    def method(self):
        """A method."""
        pass

    def another_method(self):
        def nested():
            pass
        return nested


def top_function():
    """A top-level function."""
    pass


@some_decorator
def decorated_function():
    pass


@some_decorator
class DecoratedClass:
    def decorated_method(self):
        pass
