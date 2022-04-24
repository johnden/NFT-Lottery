from ast import For
import os
import json


def export_to(jd, file_path):
    # jd 必须是字典类型, file_path 是你要保存的文件路径，比如  ./path/to/file.json
    file_dir = os.path.dirname(file_path)
    # 判断目录是否存在，否则创建目录
    if not os.path.exists(file_dir):
        os.makedirs(file_dir)

    text = json.dumps(jd)
    with open(file_path, 'w+') as fp:
        fp.write(text)


if __name__ == '__main__':
    # 调用示例
    for i in range(711):
        # print(i)
        content = {"name": "LowCostCosplay #{0}".format(i),"image": "https://gateway.pinata.cloud/ipfs/QmYZj3n21q973pUoeqNrvcVWS9r6e8UDCXBdMcMkw86Pj4/{0}.jpg".format(i)}
        export_to(content, './storage/{0}.json'.format(i))
