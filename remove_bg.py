import cv2
import numpy as np
from PIL import Image

def remove_white_background(input_path, output_path):
    # Load image
    img = cv2.imread(input_path, cv2.IMREAD_UNCHANGED)
    
    # Convert to RGBA if not already
    if img.shape[2] == 3:
        img = cv2.cvtColor(img, cv2.COLOR_BGR2BGRA)
    
    # Define white threshold
    lower_white = np.array([240, 240, 240, 255])
    upper_white = np.array([255, 255, 255, 255])
    
    # Create mask for white pixels
    mask = cv2.inRange(img, lower_white, upper_white)
    
    # Invert mask (keep non-white)
    mask_inv = cv2.bitwise_not(mask)
    
    # Set alpha channel of white pixels to 0
    img[:, :, 3] = cv2.bitwise_and(img[:, :, 3], mask_inv)
    
    # Save
    cv2.imwrite(output_path, img)
    print(f"Saved transparent image to {output_path}")

input_path = "/Users/adithyaanand/.gemini/antigravity/brain/3a2f1c38-284e-4fe7-bb05-b823fb5791b0/uploaded_image_1_1764160158745.png"
output_path = "/Users/adithyaanand/.gemini/antigravity/brain/3a2f1c38-284e-4fe7-bb05-b823fb5791b0/final_transparent_monster.png"

remove_white_background(input_path, output_path)
