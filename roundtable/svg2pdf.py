#! /usr/bin/python
#
# FROM: http://stackoverflow.com/questions/5835795/generating-pdfs-from-svg-input
# Does not work, draws only crissross lines.

from svglib.svglib import svg2rlg
from reportlab.graphics import renderPDF

drawing = svg2rlg("test.svg")
renderPDF.drawToFile(drawing, "test.pdf")
