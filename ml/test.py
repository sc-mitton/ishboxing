import cv2
import supervision as sv
from inference import get_model

model = get_model(model_id="ish")
image = cv2.imread("image.png")
results = model.infer(image)[0]
detections = sv.KeyPoints.from_inference(results)

print(detections)

edge_annotator = sv.EdgeAnnotator(
    color=sv.Color.GREEN,
    thickness=5
)
annotated_frame = edge_annotator.annotate(
    scene=image.copy(),
    key_points=detections
)

sv.plot_image(annotated_frame)
