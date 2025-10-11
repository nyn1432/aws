class Node:
    def __init__(self, value):
        self.value = value
        self.left = None
        self.right = None

def sorted_array_to_bst(arr):
    if not arr:
        return None
    
    mid = len(arr) // 2
    root = Node(arr[mid])
    root.left = sorted_array_to_bst(arr[:mid])
    root.right = sorted_array_to_bst(arr[mid + 1:])
    return root

def inorder_traversal(root):
    if root:
        inorder_traversal(root.left)
        print(root.value, end=" ")
        inorder_traversal(root.right)

def preorder_traversal(root):
    if root:
        print(root.value, end=" ")
        preorder_traversal(root.left)
        preorder_traversal(root.right)

def postorder_traversal(root):
    if root:
        postorder_traversal(root.left)
        postorder_traversal(root.right)
        print(root.value, end=" ")

def unsorted_array_to_bst(arr):
    if not arr:
        return None
    
    arr.sort()
    return sorted_array_to_bst(arr)

# Two Sum Problem
target = 10
nums = [4, 7, 2, 5, 9, 6]
def two_sum(nums, target):
    # Dictionary to store number and its index
    num_to_index = {}
    for i, num in enumerate(nums):
        complement = target - num
        if complement in num_to_index:
            return [num_to_index[complement], i]
        num_to_index[num] = i
    return []


arr = [3, 1, 4, 2, 5, 9, 6, 8, 7]
bst_root = unsorted_array_to_bst(arr)
print(bst_root.value)  # Output the root value of the BST
print("Inorder Traversal of the constructed BST:")
inorder_traversal(bst_root)
print("\nPreorder Traversal of the constructed BST:")
preorder_traversal(bst_root)
print("\nPostorder Traversal of the constructed BST:")
postorder_traversal(bst_root)
two_sum_result = two_sum(nums, target)
print(f"\nTwo indexes that add up to {target}: {two_sum_result}")



