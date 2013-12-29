
class TreeVisitor( object ):

    def __init__(self, visitor):
        if visitor:
            self.visit_node = visitor.visit_node
            self.depart_node = departor.depart_node

    def visit(self, tree ):
        self.visit_node(tree)
        for s in tree.subnodes:
            self.visit( s )
        self.depart_node(tree)
    
    def visit_node(self, node):
        pass
    def depart_node(self, node):
        pass


class TreeCloner( TreeVisitor ):
   
    """
    XXX: pehraps clone is a misnomer, it copies the ITreeNode
    """

    def visit_node(self, node):
        pass
    def depart_node(self, node):
        pass


