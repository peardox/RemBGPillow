#  This demo requires  the module pillow (PIL)
#  You can use "pip install Pillow" from a command prompt to install Pillow

from io import BytesIO
from PIL import Image
import sys

def ProcessImage(data):
  print(sys.version)
  stream = BytesIO(data)
  im = Image.open(stream)
  print ("Processing image %s of %d bytes" % (im.format, len(data)))
  new_im = im.rotate(90, expand=True)
  new_im.format = im.format
  return new_im
  
def ImageToBytes(image):
  stream = BytesIO()
  image.save(stream, image.format)
  return stream.getvalue()
