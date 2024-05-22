from functools import wraps
from typing import get_type_hints, _GenericAlias

def type_check(func):
    """
    A decorator to enforce type checking on function arguments.

    This decorator inspects the type hints of the decorated function and checks if the provided arguments
    match the expected types. If an argument does not match the expected type, a TypeError is raised.

    It also handles generic types like List[Type].

    Parameters:
        func (callable): The function to decorate.

    Returns:
        callable: The decorated function with type checking.
    """
    @wraps(func)
    def wrapper(*args, **kwargs):
        """
        The wrapper function that performs type checking.

        Parameters:
            *args: Positional arguments passed to the decorated function.
            **kwargs: Keyword arguments passed to the decorated function.

        Raises:
            TypeError: If an argument does not match the expected type.
        """
        hints = get_type_hints(func)
        all_args = kwargs.copy()
        all_args.update(dict(zip(func.__code__.co_varnames, args)))

        for param, arg in all_args.items():
            if param in hints:
                expected_type = hints[param]

                if isinstance(expected_type, _GenericAlias):  # For handling generics like List[Path]
                    origin_type = expected_type.__origin__
                    if origin_type == list:
                        item_type = expected_type.__args__[0]
                        if not (isinstance(arg, list) and all(isinstance(item, item_type) for item in arg)):
                            raise TypeError(f"Argument '{param}' must be a list of {item_type}, got {type(arg).__name__}")
                    else:
                        if not isinstance(arg, origin_type):
                            raise TypeError(f"Argument '{param}' must be {origin_type}, got {type(arg).__name__}")
                else:
                    if not isinstance(arg, expected_type):
                        raise TypeError(f"Argument '{param}' must be {expected_type}, got {type(arg).__name__}")

        return func(*args, **kwargs)

    return wrapper
