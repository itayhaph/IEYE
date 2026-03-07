import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

# ==========================================
# 1. Test results matrix
# ==========================================
# TP = correctly identified closed eyes
# TN = correctly identified open eyes
# FP = open eyes incorrectly classified as closed
# FN = closed eyes incorrectly classified as open

test_results = [
    # -------------------------------------------------------------------------------------
    # Day - Without Glasses
    # -------------------------------------------------------------------------------------
    {"Mode": "Vision", "Lighting": "Day", "Glasses": "No", "Yaw_Angle": 0,  "TP": 5, "TN": 5, "FP": 0, "FN": 0},
    {"Mode": "Vision", "Lighting": "Day", "Glasses": "No", "Yaw_Angle": 15, "TP": 5, "TN": 5, "FP": 0, "FN": 0},
    {"Mode": "Vision", "Lighting": "Day", "Glasses": "No", "Yaw_Angle": 30, "TP": 3, "TN": 5, "FP": 0, "FN": 2},
    {"Mode": "Vision", "Lighting": "Day", "Glasses": "No", "Yaw_Angle": 45, "TP": 1, "TN": 5, "FP": 0, "FN": 5},
    
    {"Mode": "ARKit",  "Lighting": "Day", "Glasses": "No", "Yaw_Angle": 0,  "TP": 5, "TN": 5, "FP": 0, "FN": 0},
    {"Mode": "ARKit",  "Lighting": "Day", "Glasses": "No", "Yaw_Angle": 15, "TP": 5, "TN": 5, "FP": 0, "FN": 0},
    {"Mode": "ARKit",  "Lighting": "Day", "Glasses": "No", "Yaw_Angle": 30, "TP": 4, "TN": 5, "FP": 0, "FN": 1},
    {"Mode": "ARKit",  "Lighting": "Day", "Glasses": "No", "Yaw_Angle": 45, "TP": 3, "TN": 5, "FP": 0, "FN": 2},

    # -------------------------------------------------------------------------------------
    # Day - With Glasses
    # -------------------------------------------------------------------------------------
    {"Mode": "Vision", "Lighting": "Day", "Glasses": "Yes", "Yaw_Angle": 0,  "TP": 5, "TN": 5, "FP": 0, "FN": 0},
    {"Mode": "Vision", "Lighting": "Day", "Glasses": "Yes", "Yaw_Angle": 15, "TP": 5, "TN": 5, "FP": 0, "FN": 0},
    {"Mode": "Vision", "Lighting": "Day", "Glasses": "Yes", "Yaw_Angle": 30, "TP": 4, "TN": 5, "FP": 0, "FN": 1},
    {"Mode": "Vision", "Lighting": "Day", "Glasses": "Yes", "Yaw_Angle": 45, "TP": 0, "TN": 5, "FP": 0, "FN": 5},
    
    {"Mode": "ARKit",  "Lighting": "Day", "Glasses": "Yes", "Yaw_Angle": 0,  "TP": 5, "TN": 5, "FP": 0, "FN": 0},
    {"Mode": "ARKit",  "Lighting": "Day", "Glasses": "Yes", "Yaw_Angle": 15, "TP": 4, "TN": 5, "FP": 0, "FN": 1},
    {"Mode": "ARKit",  "Lighting": "Day", "Glasses": "Yes", "Yaw_Angle": 30, "TP": 2, "TN": 5, "FP": 0, "FN": 3},
    {"Mode": "ARKit",  "Lighting": "Day", "Glasses": "Yes", "Yaw_Angle": 45, "TP": 2, "TN": 4, "FP": 0, "FN": 3},

    # -------------------------------------------------------------------------------------
    # Night - Without Glasses
    # -------------------------------------------------------------------------------------
    {"Mode": "Vision", "Lighting": "Night", "Glasses": "No", "Yaw_Angle": 0,  "TP": 5, "TN": 5, "FP": 0, "FN": 0},
    {"Mode": "Vision", "Lighting": "Night", "Glasses": "No", "Yaw_Angle": 15, "TP": 0, "TN": 5, "FP": 0, "FN": 5},
    {"Mode": "Vision", "Lighting": "Night", "Glasses": "No", "Yaw_Angle": 30, "TP": 0, "TN": 5, "FP": 0, "FN": 5},
    {"Mode": "Vision", "Lighting": "Night", "Glasses": "No", "Yaw_Angle": 45, "TP": 0, "TN": 5, "FP": 0, "FN": 5},
    
    {"Mode": "ARKit",  "Lighting": "Night", "Glasses": "No", "Yaw_Angle": 0,  "TP": 5, "TN": 5, "FP": 0, "FN": 0},
    {"Mode": "ARKit",  "Lighting": "Night", "Glasses": "No", "Yaw_Angle": 15, "TP": 2, "TN": 5, "FP": 0, "FN": 3},
    {"Mode": "ARKit",  "Lighting": "Night", "Glasses": "No", "Yaw_Angle": 30, "TP": 0, "TN": 5, "FP": 0, "FN": 5},
    {"Mode": "ARKit",  "Lighting": "Night", "Glasses": "No", "Yaw_Angle": 45, "TP": 0, "TN": 5, "FP": 0, "FN": 5},

    # -------------------------------------------------------------------------------------
    # Night - With Glasses
    # -------------------------------------------------------------------------------------
    {"Mode": "Vision", "Lighting": "Night", "Glasses": "Yes", "Yaw_Angle": 0,  "TP": 0, "TN": 5, "FP": 0, "FN": 5},
    {"Mode": "Vision", "Lighting": "Night", "Glasses": "Yes", "Yaw_Angle": 15, "TP": 0, "TN": 5, "FP": 0, "FN": 5},
    {"Mode": "Vision", "Lighting": "Night", "Glasses": "Yes", "Yaw_Angle": 30, "TP": 0, "TN": 5, "FP": 0, "FN": 5},
    {"Mode": "Vision", "Lighting": "Night", "Glasses": "Yes", "Yaw_Angle": 45, "TP": 0, "TN": 5, "FP": 0, "FN": 5},
    
    {"Mode": "ARKit",  "Lighting": "Night", "Glasses": "Yes", "Yaw_Angle": 0,  "TP": 1, "TN": 5, "FP": 0, "FN": 4},
    {"Mode": "ARKit",  "Lighting": "Night", "Glasses": "Yes", "Yaw_Angle": 15, "TP": 0, "TN": 5, "FP": 0, "FN": 5},
    {"Mode": "ARKit",  "Lighting": "Night", "Glasses": "Yes", "Yaw_Angle": 30, "TP": 0, "TN": 5, "FP": 0, "FN": 5},
    {"Mode": "ARKit",  "Lighting": "Night", "Glasses": "Yes", "Yaw_Angle": 45, "TP": 0, "TN": 5, "FP": 0, "FN": 5},
]

# ==========================================
# 2. Calc Accuracy And Recall
# ==========================================
df = pd.DataFrame(test_results)

df['Yaw_Angle'] = df['Yaw_Angle'].astype(str) + '°'
df['Accuracy'] = np.where((df['TP'] + df['TN'] + df['FP'] + df['FN']) > 0,
                          ((df['TP'] + df['TN']) / (df['TP'] + df['TN'] + df['FP'] + df['FN'])) * 100, 0)
df['Recall'] = np.where((df['TP'] + df['FN']) > 0,
                        (df['TP'] / (df['TP'] + df['FN'])) * 100, 0)

# ==========================================
# 3. Grid Plots
# ==========================================
sns.set_theme(style="whitegrid")
angle_order = ['0°', '15°', '30°', '45°']

def format_axes_and_labels(plot_obj, y_label):
    for ax in plot_obj.axes.flat:
        ax.tick_params(labelbottom=True)
        ax.set_xlabel("Yaw Angle")
        ax.set_ylabel(y_label)
        
        for p in ax.patches:
            height = p.get_height()
            if pd.notnull(height) and height > 0:
                ax.annotate(f"{height:.0f}%",
                            (p.get_x() + p.get_width() / 2., height),
                            ha='center', va='bottom', fontsize=9, color='black', xytext=(0, 3), textcoords='offset points')

g_acc = sns.catplot(
    data=df, x='Yaw_Angle', y='Accuracy', hue='Mode',
    col='Lighting', row='Glasses', kind='bar',
    palette=['#3498db', '#9b59b6'], height=4.5, aspect=1.5,
    margin_titles=True, order=angle_order
)
g_acc.set_titles(col_template="Lighting: {col_name}", row_template="Glasses: {row_name}", size=12, fontweight='bold')
g_acc.set(ylim=(0, 115))
g_acc.fig.suptitle('Accuracy: Vision vs ARKit Across All Conditions', y=1.05, fontsize=16, fontweight='bold')

format_axes_and_labels(g_acc, "Accuracy (%)")

plt.subplots_adjust(hspace=0.4)
plt.savefig('Accuracy_Grid_Degrees.png', dpi=300, bbox_inches='tight')

g_rec = sns.catplot(
    data=df, x='Yaw_Angle', y='Recall', hue='Mode',
    col='Lighting', row='Glasses', kind='bar',
    palette=['#3498db', '#9b59b6'], height=4.5, aspect=1.5,
    margin_titles=True, order=angle_order
)
g_rec.set_titles(col_template="Lighting: {col_name}", row_template="Glasses: {row_name}", size=12, fontweight='bold')
g_rec.set(ylim=(0, 115))
g_rec.fig.suptitle('Recall (Sensitivity): Vision vs ARKit Across All Conditions', y=1.05, fontsize=16, fontweight='bold')

format_axes_and_labels(g_rec, "Recall (%)")

plt.subplots_adjust(hspace=0.4)
plt.savefig('Recall_Grid_Degrees.png', dpi=300, bbox_inches='tight')
print("Graphs successfully generated with degrees on the X-axis!")
