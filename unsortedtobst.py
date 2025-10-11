class Node:
    def __init__(self, value):
        self.value = value
        self.left = None
        self.right = None

def insert_bst(root, value):
    if root is None:
        return Node(value)
    if value < root.value:
        root.left = insert_bst(root.left, value)
    else:
        root.right = insert_bst(root.right, value)
    return root

def inorder_traversal(root):
    if root:
        inorder_traversal(root.left)
        print(root.value, end=" ")
        inorder_traversal(root.right)

arr = [3, 1, 4, 2, 5, 9, 6, 8, 7]
root = None
for num in arr:
    root = insert_bst(root, num)

print("Inorder Traversal of the constructed BST:")
inorder_traversal(root)
