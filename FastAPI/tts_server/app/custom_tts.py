import os
import shutil
import torch
import requests
from tqdm import tqdm
import zipfile
from openvoice import se_extractor
from openvoice.api import ToneColorConverter
from melo.api import TTS

class Custom_TTS:
    def __init__(self, model_path='checkpoints_v2', output_path='output'):
        '''
        model_path: TTS를 위한 베이스 모델, 음성 변조를 위한 베이스 모델이 위치한 path
        '''
        print('본 코드를 개발한 Repo. 입니다: https://github.com/Nyan-SouthKorea/RealTime_zeroshot_TTS_ko')
        print('다음 Repo.를 참조하여 개발한 모듈입니다: https://github.com/myshell-ai/OpenVoice')
        self.model_path = model_path
        self.result_cnt = 0
        self.output_path = output_path

        # cuda 확인
        self.check_cuda()

        # output 폴더 삭제 후 시작
        if os.path.exists(self.output_path):
            shutil.rmtree(self.output_path)

    def check_cuda(self):
        '''cuda 환경 확인'''
        self.device = "cuda:0" if torch.cuda.is_available() else "cpu"
        print(f'사용 환경(cude): {self.device}')

    def checkpoint_download(self):
        '''
        모델의 pre-trained checkpoint가 있는지 확인하고 없으면 다운로드 함
        - 모델의 폴더만 확인하기 때문에, 폴더 안에 모델 변경이 있어도 유효성 검사를 수행하지 않음
        - 단순히 폴더가 없으면 다시 다운로드 하는 로직임
        '''
        if os.path.exists(self.model_path) == False:
            download = Down_and_extract()
            ret = download.do(url="https://myshell-public-repo-host.s3.amazonaws.com/openvoice/checkpoints_v2_0417.zip", filename="checkpoints_v2_0417.zip")
            if ret == False:
                with open('./error_txt.txt', 'r', encoding='utf-8-sig') as f:
                    error_txt = f.read()
                    print(error_txt)

    def set_model(self, language='KR'):
        '''
        모델 설정
        language: 언어 입력(en-au, en-br, en-default, en-india, en-newest, en-us, es, fr, jp, kr, zh)
        '''
        self.language = language
        
        # pre-trained 모델 다운로드
        self.checkpoint_download()

        # 톤 변경 모델 로드
        self.tone_color_converter = ToneColorConverter(f'{self.model_path}/converter/config.json', device=self.device)
        self.tone_color_converter.load_ckpt(f'{self.model_path}/converter/checkpoint.pth')
        print('톤 변경 모델 로드 완료')

        # TTS 모델 선언
        self.tts_model = TTS(language=self.language, device=self.device)
        print('TTS 모델 로드 완료')

        # 기본 화자 음성 임베딩: TTS 모델이 생성한 음성을 음색 변환 모델이 입력할 때, 원본 화자의 음색 정보를 제공함
        speaker_ids = self.tts_model.hps.data.spk2id
        for speaker_key in speaker_ids.keys():
            self.speaker_id = speaker_ids[speaker_key]
            speaker_key = speaker_key.lower().replace('_', '-')
        self.source_se = torch.load(f'{self.model_path}/base_speakers/ses/{speaker_key}.pth', map_location=self.device)
        print('기본 화자 음성 임베딩 완료')

    def get_reference_speaker(self, speaker_path, vad=True):
        '''
        흉내낼 목소리를 입력해주는 함수. 
        - 논문 상 최소 44초 길이 이상의 음성을 넣으라고 되어있음
        - base 목소리가 여자이기 때문에, 조금의 실험을 해본 결과 남자 목소리 보다는 여자 목소리를 더 잘 따라하는 경향을 보임
        - 꼭 mp3일 필요 없고 갤럭시 휴대폰 기본 녹음 포맷인 m4a도 문제 없었음

        path: 복사할 음성의 상대 경로를 입력
        vad: 목소리 감지 기능 켜기/끄기. 켤 경우 음성 내에서 목소리가 있는 부분만 전처리 함
        '''
        # 톤 컬러 임베딩
        self.target_se, audio_name = se_extractor.get_se(speaker_path, self.tone_color_converter, vad=vad)
        print('목소리 톤 임베딩 완료')

    def make_speech(self, text, speed=1.2):
        '''
        텍스트를 입력하면 TTS를 수행하는 함수. mp3를 생성하여 로컬에 저장함
        text: 변환을 원하는 언어를 입력
        output_path: TTS 결과물이 출력되는 경로
        speed: 음성 재생 속도. 1.1이 자연스러운 것 같음
        '''
        try:
            # 경로 설정, 폴더 생성
            src_path = f'{self.output_path}/tmp.wav'
            os.makedirs(self.output_path, exist_ok=True)

            # TTS 수행
            self.tts_model.tts_to_file(text, self.speaker_id, src_path, speed=speed)
            print('TTS 생성 완료')

            '''
            # 목소리 변조 수행
            self.tone_color_converter.convert(audio_src_path=src_path, 
                                            src_se=self.source_se, 
                                            tgt_se=self.target_se, 
                                            output_path=f'{self.output_path}/result_{self.result_cnt}.wav')
            print('목소리 변조 완료')
            self.result_cnt += 1'''
        except Exception as e:
            print(e)

class Down_and_extract:
    def do(self, url, filename):
        try:
            # HTTP 응답에서 Content-Length(파일 크기) 가져오기
            response = requests.get(url, stream=True)
            total_size = int(response.headers.get('content-length', 0))

            # 다운로드 진행을 표시하는 tqdm 설정
            with open(filename, "wb") as file, tqdm(
                desc=filename,
                total=total_size,
                unit='B',
                unit_scale=True,
                unit_divisor=1024,
            ) as bar:
                for data in response.iter_content(chunk_size=1024):
                    file.write(data)
                    bar.update(len(data))

            print(f"{filename} 다운로드 완료!")

            # 압축 해제 진행률 표시
            with zipfile.ZipFile(filename, 'r') as zip_ref:
                # 압축된 파일의 전체 크기를 계산
                total_unzipped_size = sum((zinfo.file_size for zinfo in zip_ref.infolist()))

                # 압축 해제 진행률을 표시하는 tqdm 설정
                with tqdm(total=total_unzipped_size, unit='B', unit_scale=True, unit_divisor=1024, desc="Extracting") as bar:
                    for zinfo in zip_ref.infolist():
                        extracted_file_path = zip_ref.extract(zinfo, './')
                        # 압축 해제된 파일 크기만큼 진행률을 업데이트
                        bar.update(zinfo.file_size)
            print(f"{filename} 압축 해제 완료!")
            return True
        except Exception as e:
            print(f'압축 해제 문제 발생: \n{e}')
            return False