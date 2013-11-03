import sys
sys.path.append('/Library/Python/2.6/site-packages/snake_guice-0.3-py2.6.egg')

# Domain objects, using injection where required
from snakeguice import inject, annotate


class IBaz(object):
	pass

class IBar(object):
	"""This will be used an the interface when creating a binding."""

class SmallBlockBar(object):
	"""Implementation of a small block bar."""

class Foo(object):
	"""An implementation of a car.""" 

	@inject(bar=IBar, foo=IBaz)
	@annotate(foo="test_foo_8325")
	def __init__(self, bar, foo):
		self.bar = bar

class Resourcer(object):
	pass


# Module

class RightDoor: pass
class SmallBlockBar: pass
class SnakeModule(object):
	def configure(self, binder):
		binder.bind(IBar, to=SmallBlockBar)
		binder.bind(IDoor, annotated_with='test_foo_8325', to=RightDoor)

		#binder.bind(ICommand, to=Resourcer)


# Main

from snakeguice import Injector


def main(args):
	injector = Injector(SnakeModule())
	car = injector.get_instance(Foo) 
   
	print mod
	print injector
	print car, car.bar
	
	assert isinstance(car, Foo)
	assert isinstance(car.bar, SmallBlockBar)


if __name__ == '__main__':
	main([])

